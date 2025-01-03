function Publish-StagingModuleLocal {
	<#
	.SYNOPSIS
		Deploys modules to a local path.
	
	.DESCRIPTION
		Deploys modules to a local path.
	
	.PARAMETER Path
		The path from where modules are copied.
	
	.PARAMETER TargetPath
		The destination path information where to deploy the modules.
		Not a string, but the return objects from Resolve-RemotePath (which contrary to its name is also capable of resolving local paths)
	
	.PARAMETER Force
		Redeploy a module that already exists in the target path.
		By default it will skip modules that do already exist in the target path.
	
	.PARAMETER Cmdlet
		The $PSCmdlet variable of the calling command, used to ensure errors happen within the scope of the caller, hiding this internal helper command from the user.
	
	.EXAMPLE
		PS C:\> Publish-StagingModuleLocal -Path $stagingDirectory -TargetPath $targets -Force:$Force -Cmdlet $PSCmdlet

		Deploys all modules under $stagingDirectory to the target paths/computers in $targets.
		Will overwrite existing modules if $Force is $true.
	#>
	[CmdletBinding()]
	param (
		[string]
		$Path,

		$TargetPath,

		[switch]
		$Force,

		$Cmdlet
	)

	$msgParam = @{
		PSCmdlet = $Cmdlet
	}
	$publishCommon = @{
		ComputerName = $env:COMPUTERNAME
	}
	$oldSuffix = "old_$(Get-Random -Minimum 100 -Maximum 999)"
	$killIt = $ErrorActionPreference -eq 'Stop'

	foreach ($module in Get-ChildItem -Path $Path) {
		foreach ($version in Get-ChildItem -Path $module.FullName) {
			foreach ($destination in $TargetPath.Results) {
				if (-not $destination.Exists) { continue }

				$publishCommon.Path = $destination.Path
				$publishCommon.Module = $module.Name
				$publishCommon.Version = $version.Name

				$testPath = Join-Path -Path $destination.Path -ChildPath "$($module.Name)/$($version.Name)/$($module.DirectoryName).psd1"
				$alreadyExists = Test-Path -Path $testPath
				if ($alreadyExists -and -not $Force) {
					Write-PSFMessage @msgParam -String 'Publish-StagingModule.Skipping.AlreadyExists' -StringValues $module.Name, $version.Name, $destination.Path
					continue
				}

				$targetVersionRoot = Join-Path -Path $destination.Path -ChildPath $module.Name
				$targetVersionDirectory = Join-Path -Path $destination.Path -ChildPath "$($module.Name)/$($version.Name)"

				# Rename old version
				if ($alreadyExists) {
					Invoke-PSFProtectedCommand -ActionString 'Publish-StagingModule.Deploying.RenameOld' -ActionStringValues $module.Name, $version.Name -Target $TargetPath -ScriptBlock {
						Rename-Item -LiteralPath $targetVersionDirectory -NewName "$($version.Name)_$oldSuffix" -Force -ErrorAction Stop
					} -PSCmdlet $Cmdlet -EnableException $killIt -Continue -ErrorEvent {
						$result = New-PublishResult @publishCommon -Success $false -Message "Failed to rename old version: $_"
						$PSCmdlet.WriteObject($result, $true)
					}
				}

				# Deploy New Version
				Invoke-PSFProtectedCommand -ActionString 'Publish-StagingModule.Deploying.Local' -ActionStringValues $module.Name, $version.Name, $destination.Path -Target $TargetPath -ScriptBlock {
					if (-not (Test-Path $targetVersionRoot)) { $null = New-Item -Path $destination.Path -Name $module.Name -ItemType Directory -Force }
					Copy-Item -Path $version.FullName -Destination $targetVersionRoot -Recurse -Force
				} -PSCmdlet $Cmdlet -EnableException $killIt -Continue -ErrorEvent {
					# Rollback to old version in case of deployment error
					if ($alreadyExists) {
						Remove-Item -Path $targetVersionDirectory -Force -ErrorAction SilentlyContinue
						Rename-Item -LiteralPath "$($targetVersionDirectory)_$oldSuffix" -NewName $version.Name -Force -ErrorAction Continue # Don't interfere with the formal error handling, but show extra error if applicable
					}

					$result = New-PublishResult @publishCommon -Success $false -Message "Failed to deploy version: $_"
					$PSCmdlet.WriteObject($result, $true)
				}

				# Remove old version
				if ($alreadyExists) {
					Invoke-PSFProtectedCommand -ActionString 'Publish-StagingModule.Deploying.DeleteOld' -ActionStringValues $module.Name, $version.Name -Target $TargetPath -ScriptBlock {
						Remove-Item -LiteralPath "$($targetVersionDirectory)_$oldSuffix" -Force -ErrorAction Stop -Recurse
					} -PSCmdlet $Cmdlet -EnableException $false -Continue -ErrorEvent {
						$result = New-PublishResult @publishCommon -Success $true -Message "Failed to cleanup previous version: $_"
						$PSCmdlet.WriteObject($result, $true)
					}
				}

				New-PublishResult @publishCommon -Success $true
			}
		}
	}
}