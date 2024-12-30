function Publish-StagingModuleRemote {
	<#
		.SYNOPSIS
		Deploys modules to a remote path.
	
	.DESCRIPTION
		Deploys modules to a remote path.
		This happens in parallel using psframework Runspace Workflows.
	
	.PARAMETER Path
		The path from where modules are copied.
	
	.PARAMETER TargetPath
		The destination path information where to deploy the modules.
		Not a string, but the return objects from Resolve-RemotePath.
		This object also includes the PSSession objects needed to execute the transfer.
	
	.PARAMETER ThrottleLimit
		Up to how many computers to deploy the modules to in parallel.
		Defaults to: 5
		Default can be configured under the 'PSFramework.NuGet.Remoting.Throttling' setting.

	.PARAMETER Force
		Redeploy a module that already exists in the target path.
		By default it will skip modules that do already exist in the target path.
	
	.EXAMPLE
		PS C:\> Publish-StagingModuleRemote -Path $stagingDirectory -TargetPath $targets -Force:$Force -Cmdlet $PSCmdlet

		Deploys all modules under $stagingDirectory to the target paths/computers in $targets.
		Will overwrite existing modules if $Force is $true.
	#>
	[CmdletBinding()]
	param (
		[string]
		$Path,

		$TargetPath,

		[ValidateRange(1, [int]::MaxValue)]
		[int]
		$ThrottleLimit = 5,

		[switch]
		$Force
	)

	begin {
		#region Worker Code
		$code = {
			param (
				$TargetPath
			)

			<#
			Inherited Variables:
			- $Path - Where the modules to publish lie
			- $Force - Whether to overwrite/redeploy modules that already exist in that path in that version
			#>

			$PSDefaultParameterValues['Write-PSFMessage:ModuleName'] = 'PSFramework.NuGet'
			$PSDefaultParameterValues['Write-PSFMessage:FunctionName'] = 'Publish-StagingModule'

			#region Functions
			function Get-GlobalFailResult {
				[CmdletBinding()]
				param (
					[string]
					$ComputerName,

					[string]
					$Path,

					[System.Management.Automation.ErrorRecord]
					$ErrorRecord
				)

				foreach ($module in Get-ChildItem -Path $Path) {
					foreach ($version in Get-ChildItem -Path $module.FullName) {
						New-PublishResult -ComputerName $ComputerName -Module $module.Name -Version $version.Name -Success $false -Path 'n/a' -Message $ErrorRecord
					}
				}
			}
			#endregion Functions

			trap {
				Write-PSFMessage -Level Error -String 'Publish-StagingModule.Error.General' -StringValues $TargetPath.ComputerName -ErrorRecord $_

				#region Cleanup Staging Directory
				if ($stagingDirectory) {
					$null = Invoke-SessionCommand @sessionCommon -Code {
						param ($Path)
						Remove-Item -Path $Path -Recurse -Force -ErrorAction Ignore
					} -ArgumentList $stagingDirectory
				}
				#endregion Cleanup Staging Directory

				Get-GlobalFailResult -Path $Path -ComputerName $TargetPath.ComputerName -ErrorRecord $_

				$__PSF_Workflow.Data.Failed[$TargetPath.ComputerName] = $true
				$__PSF_Workflow.Data.Completed[$TargetPath.ComputerName] = $true
				$null = $__PSF_Workflow.Data.InProgress.TryRemove($TargetPath.ComputerName, [ref]$null)
				return
			}

			$publishCommon = @{
				ComputerName = $TargetPath.ComputerName
			}
			$sessionCommon = @{
				Session = $TargetPath.Session.Session
			}

			$oldSuffix = "old_$(Get-Random -Minimum 100 -Maximum 999)"
			$anyFailed = $false

			#region Prepare Staging Directory
			# This allows us to minimize the cutover time, when replacing an existing module
			$stagingResult = Invoke-SessionCommand @sessionCommon -Code {
				$tempDir = $env:TEMP
				if (-not $tempDir) {
					$localAppData = $env:LOCALAPPDATA
					if (-not $localAppData -and -not $IsLinux -and -not $IsMacOS) { $localAppData = [Environment]::GetFolderPath("LocalApplicationData") }
					if (-not $localAppData -and $Env:XDG_CONFIG_HOME) { $localAppData = $Env:XDG_CONFIG_HOME }
					if (-not $localAppData) { $localAppData = Join-Path -Path $HOME -ChildPath '.config' }
					$tempDir = Join-Path -Path $localAppData -ChildPath 'Temp'
				}
				if (-not (Test-Path -Path $tempDir)) {
					New-Item -Path $tempDir -ItemType Directory -Force -ErrorAction Stop
				}
				$stagingPath = Join-Path -Path $tempDir -ChildPath "PsfGet-$(Get-Random)"
				(New-Item -Path $stagingPath -ItemType Directory -Force -ErrorAction Stop).FullName
			}
			if (-not $stagingResult.Success) {
				Write-PSFMessage -Level Warning -String 'Publish-StagingModule.Remote.Error.TempStagingSetup' -StringValues $TargetPath.ComputerName, $stagingResult.Error -Tag error, temp, setup
				throw $stagingResult.Error
			}
			$stagingDirectory = $stagingResult.Data
			#endregion Prepare Staging Directory

			#region Send Modules
			foreach ($module in Get-ChildItem -Path $Path) {
				foreach ($version in Get-ChildItem -Path $module.FullName) {
					foreach ($destination in $TargetPath.Results) {
						if (-not $destination.Exists) { continue }

						#region Verify Existence
						$publishCommon.Path = $destination.Path
						$publishCommon.Module = $module.Name
						$publishCommon.Version = $version.Name

						$testPath = Join-Path -Path $destination.Path -ChildPath "$($module.Name)/$($version.Name)/$($module.Name).psd1"
						$alreadyExists = Invoke-Command -Session $TargetPath.Session.Session -ScriptBlock {
							param ($TestPath)
							Test-Path -Path $TestPath
						} -ArgumentList $testPath

						if ($alreadyExists -and -not $Force) {
							Write-PSFMessage -String 'Publish-StagingModule.Remote.Skipping.AlreadyExists' -StringValues $TargetPath.ComputerName, $module.Name, $version.Name -Target ("$($module.Name) ($($version.Name))")
							New-PublishResult @publishCommon -Success $true -Message 'Module already deployed'
							continue
						}
						#endregion Verify Existence
		
						$targetStagingRoot = Join-Path -Path $stagingDirectory -ChildPath $module.Name
						$targetStagingVersionDirectory = Join-Path -Path $targetStagingRoot -ChildPath $version.Name
						$targetVersionRoot = Join-Path -Path $destination.Path -ChildPath $module.Name
						$targetVersionDirectory = Join-Path -Path $targetVersionRoot -ChildPath $version.Name

						#region Send Module to Staging
						Write-PSFMessage -String 'Publish-StagingModule.Remote.DeployStaging' -StringValues $TargetPath.ComputerName, $module.Name, $version.Name, $targetStagingRoot -Target ("$($module.Name) ($($version.Name))")
						$createResult = Invoke-SessionCommand @sessionCommon -Code {
							param ($ModuleRoot)
							New-Item -Path $ModuleRoot -ItemType Directory -Force -ErrorAction Stop
						} -ArgumentList $targetStagingRoot
						if (-not $createResult.Success) {
							Write-PSFMessage -String 'Publish-StagingModule.Remote.DeployStaging.FailedDirectory' -StringValues $TargetPath.ComputerName, $module.Name, $version.Name, $targetStagingRoot, $createResult.Error -Target ("$($module.Name) ($($version.Name))")
							New-PublishResult @publishCommon -Success $false -Message "Failed to create staging module folder $targetStagingRoot on $($TargetPath.ComputerName): $($createResult.Error)"
							$anyFailed = $true
							continue
						}
						try { Copy-Item -LiteralPath $version.FullName -Destination $targetStagingRoot -Recurse -Force -ToSession $TargetPath.Session.Session -ErrorAction Stop }
						catch {
							Write-PSFMessage -String 'Publish-StagingModule.Remote.DeployStaging.FailedCopy' -StringValues $TargetPath.ComputerName, $module.Name, $version.Name, $targetStagingRoot -Target ("$($module.Name) ($($version.Name))") -ErrorRecord $_
							New-PublishResult @publishCommon -Success $false -Message "Failed to copy module to folder $targetStagingRoot on $($TargetPath.ComputerName): $_"
							$anyFailed = $true
							continue
						}
						#endregion Send Module to Staging
		
						#region Rename old version
						if ($alreadyExists) {
							Write-PSFMessage -String 'Publish-StagingModule.Remote.Deploying.RenameOld' -StringValues $TargetPath.ComputerName, $module.Name, $version.Name, $testPath -Target ("$($module.Name) ($($version.Name))")
							$renameResult = Invoke-SessionCommand @sessionCommon -Code {
								param ($Path, $NewName)
								Rename-Item -LiteralPath $Path -NewName $NewName -ErrorAction Stop -Force
							} -ArgumentList $targetVersionDirectory, "$($version.Name)_$oldSuffix"
							if ($renameResult.Success) {
								Write-PSFMessage -String 'Publish-StagingModule.Remote.Deploying.RenameOld.Success' -StringValues $TargetPath.ComputerName, $module.Name, $version.Name, $testPath -Target ("$($module.Name) ($($version.Name))")
							}
							else {
								Write-PSFMessage -Level Warning -String 'Publish-StagingModule.Remote.Deploying.RenameOld.NoSuccess' -StringValues $TargetPath.ComputerName, $module.Name, $version.Name, $testPath, $renameResult.Error -Target ("$($module.Name) ($($version.Name))")
								$anyFailed = $true
								New-PublishResult @publishCommon -Success $false -Message "Failed to rename old version: $($renameResult.Error)"
								continue
							}
						}
						#endregion Rename old version
	
						#region Deploy New Version
						Write-PSFMessage -String 'Publish-StagingModule.Deploying.Remote' -StringValues $TargetPath.ComputerName, $module.Name, $version.Name -Target ("$($module.Name) ($($version.Name))")
						$deployResult = Invoke-SessionCommand @sessionCommon -Code {
							param ($Path, $Destination)
							if (-not (Test-Path -Path $Destination)) { $null = New-Item -Path $Destination -ItemType Directory -Force -ErrorAction Stop }
							Move-Item -Path $Path -Destination $Destination -Force -ErrorAction Stop
						} -ArgumentList $targetStagingVersionDirectory, $targetVersionRoot

						if (-not $deployResult.Success) {
							Write-PSFMessage -Level Warning -String 'Publish-StagingModule.Deploying.Remote.Failed' -StringValues $TargetPath.ComputerName, $module.Name, $version.Name, $deployResult.Error -Target ("$($module.Name) ($($version.Name))")
							$anyFailed = $true
							if (-not $alreadyExists) {
								New-PublishResult @publishCommon -Success $false -Message "Failed to deploy version: $($deployResult.Error)"
								continue
							}

							$rollbackResult = Invoke-SessionCommand @sessionCommon -Code {
								param ($Path, $TempName)
								$parent, $name = Split-Path -Path $Path
								if (Test-Path -Path $Path) { Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop }

								$original = Join-Path -Path $parent -ChildPath $TempName
								Rename-Item -Path $original -NewName $name -Force -ErrorAction Stop
							} -ArgumentList $targetVersionDirectory, "$($version.Name)_$oldSuffix"

							if ($rollbackResult.Success) {
								New-PublishResult @publishCommon -Success $false -Message "Failed to re-deploy version, rollback was successful: $($deployResult.Error)"
							}
							else {
								New-PublishResult @publishCommon -Success $false -Message "Failed to re-deploy version, rollback failed: $($deployResult.Error)"
							}
							continue
						}
						#endregion Deploy New Version

						#region Remove Old Version
						if ($alreadyExists) {
							$cleanupResult = Invoke-SessionCommand @sessionCommon -Code {
								param ($Path)
								Remove-Item -LiteralPath $Path -Force -ErrorAction Stop -Recurse
							} -ArgumentList "$($targetVersionDirectory)_$oldSuffix"

							if (-not $cleanupResult.Success) {
								New-PublishResult @publishCommon -Success $true -Message "Failed to cleanup previous version: $($cleanupResult.Error)"
								continue
							}
						}
						#endregion Remove Old Version

						New-PublishResult @publishCommon -Success $true
					}
				}
			}
			#endregion Send Modules

			#region Cleanup Staging Directory
			$null = Invoke-SessionCommand @sessionCommon -Code {
				param ($Path)
				Remove-Item -Path $Path -Recurse -Force -ErrorAction Ignore
			} -ArgumentList $stagingDirectory
			#endregion Cleanup Staging Directory
		
			$__PSF_Workflow.Data.Completed[$TargetPath.ComputerName] = $true
			if ($anyFailed) { $__PSF_Workflow.Data.Failed[$TargetPath.ComputerName] = $true }
			else { $__PSF_Workflow.Data.Success[$TargetPath.ComputerName] = $true }
			$null = $__PSF_Workflow.Data.InProgress.TryRemove($TargetPath.ComputerName, [ref]$null)
		}
		#endregion Worker Code

		# Limit Worker Count to Target Count
		if ($TargetPath.Count -lt $ThrottleLimit) { $ThrottleLimit = $TargetPath.Count }

		$workflow = New-PSFRunspaceWorkflow -Name PublishModule -Force
		$null = $workflow | Add-PSFRunspaceWorker -Name Publisher -InQueue Input -OutQueue Results -ScriptBlock $code -CloseOutQueue -Count $ThrottleLimit -Functions @{
			'New-PublishResult' = [scriptblock]::Create((Get-Command New-PublishResult).Definition)
			'Invoke-SessionCommand' = [scriptblock]::Create((Get-Command Invoke-SessionCommand).Definition)
		} -Variables @{
			Path  = $Path
			Force = $Force
		}
		$workflow | Write-PSFRunspaceQueue -Name Input -BulkValues $TargetPath -Close

		# Add Tracking for Progress Information
		$workflow.Data['InProgress'] = [System.Collections.Concurrent.ConcurrentDictionary[string, string]]::new()
		$workflow.Data['Failed'] = [System.Collections.Concurrent.ConcurrentDictionary[string, string]]::new()
		$workflow.Data['Success'] = [System.Collections.Concurrent.ConcurrentDictionary[string, string]]::new()
		$workflow.Data['Completed'] = [System.Collections.Concurrent.ConcurrentDictionary[string, string]]::new()

		$progressId = Get-Random
	}
	process {
		try {
			$workflow | Start-PSFRunspaceWorkflow
			Write-Progress -Id $progressId -Activity 'Deploying Modules'

			while ($workflow.Data.Completed.Count -lt $TargetPath.Count) {
				Start-Sleep -Seconds 1
				$status = 'In Progress: {0} | Failed: {1} | Succeeded: {2} | Completed: {3}' -f $workflow.Data.InProgress.Count, $workflow.Data.Failed.Count, $workflow.Data.Success.Count, $workflow.Data.Completed.Count
				$percent = ($workflow.Data.Completed.Count / $TargetPath.Count * 100) -as [int]
				if ($percent -gt 100) { $percent = 100 }
				Write-Progress -Id $progressId -Activity 'Deploying Modules' -Status $status -PercentComplete $percent
			}
			$workflow | Wait-PSFRunspaceWorkflow -Queue Results -Closed
		}
		finally {
			# Ensure finally executes without interruption, lest an impatient admin leads to leftover state
			Disable-PSFConsoleInterrupt
			$workflow | Stop-PSFRunspaceWorkflow
			$results = $workflow | Read-PSFRunspaceQueue -Name Results -All | Write-Output # Needs to bextra enumerated if multiple results happen in a single worker
			$workflow | Remove-PSFRunspaceWorkflow
			Enable-PSFConsoleInterrupt
			$results
		}
	}
}