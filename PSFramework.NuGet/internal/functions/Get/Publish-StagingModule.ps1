function Publish-StagingModule {
	[CmdletBinding()]
	param (
		[string]
		$Path,

		$TargetPath,

		[switch]
		$Force,

		$Cmdlet
	)
	begin {
		$msgParam = @{
			PSCmdlet = $Cmdlet
		}
		$oldSuffix = "old_$(Get-Random -Minimum 100 -Maximum 999)"
	}
	process {
		foreach ($module in Get-ChildItem -Path $Path) {
			foreach ($version in Get-ChildItem -Path $module.FullName) {
				$testPath = Join-Path -Path $TargetPath -ChildPath "$($module.Name)/$($version.Name)/$($module.DirectoryName).psd1"
				$alreadyExists = Test-Path -Path $testPath
				if ($alreadyExists -and -not $Force) {
					Write-PSFMessage @msgParam -String 'Publish-StagingModule.Skipping.AlreadyExists' -StringValues $module.Name, $version.Name
					continue
				}

				$targetVersionRoot = Join-Path -Path $TargetPath -ChildPath $module.Name
				$targetVersionDirectory = Join-Path -Path $TargetPath -ChildPath "$($module.Name)/$($version.Name)"

				# Rename old version
				if ($alreadyExists) {
					Rename-Item -LiteralPath
				}
				# Deploy New Version
				# Remove old version

				if (-not (Test-Path -Path $testPath)) {
					Invoke-PSFProtectedCommand -ActionString 'Publish-StagingModule.Deploying.Simple' -ActionStringValues $module.Name, $version.Name -Target $TargetPath -ScriptBlock {
						if (-not (Test-Path $targetVersionRoot)) { $null = New-Item -Path $TargetPath -Name $module.Name -ItemType Directory -Force }
						Copy-Item -Path $version.FullName -Destination $targetVersionRoot -Recurse -Force
					} -PSCmdlet $Cmdlet -EnableException ($ErrorActionPreference -eq 'Stop') -Continue
				}
			}
		}
	}
}