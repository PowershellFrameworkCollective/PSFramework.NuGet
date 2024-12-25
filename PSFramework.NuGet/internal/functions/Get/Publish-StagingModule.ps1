function Publish-StagingModule {
	[CmdletBinding()]
	param (
		[string]
		$Path,

		$TargetPath,

		[ValidateRange(1, [int]::MaxValue)]
		[int]
		$ThrottleLimit = 5,

		[switch]
		$Force,

		$Cmdlet
	)
	begin {
		#region Utility Functions
		function Publish-StagingModuleLocal {
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
							Write-PSFMessage @msgParam -String 'Publish-StagingModule.Skipping.AlreadyExists' -StringValues $module.Name, $version.Name
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
						Invoke-PSFProtectedCommand -ActionString 'Publish-StagingModule.Deploying.Local' -ActionStringValues $module.Name, $version.Name -Target $TargetPath -ScriptBlock {
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

		function New-PublishResult {
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
			[CmdletBinding()]
			param (
				[string]
				$ComputerName,

				[string]
				$Module,

				[string]
				$Version,

				[bool]
				$Success,

				[string]
				$Message,

				[string]
				$Path
			)

			[PSCustomObject]@{
				PSTypeName   = 'PSFramework.NuGet.PublishResult'
				Computername = $ComputerName
				Module       = $Module
				Version      = $Version
				Success      = $Success
				Message      = $Message
				Path         = $Path
			}
		}
		
		function Publish-StagingModuleRemote {
			[CmdletBinding()]
			param (
				[string]
				$Path,

				$TargetPath,

				[ValidateRange(1, [int]::MaxValue)]
				[int]
				$ThrottleLimit = 5,

				[switch]
				$Force,

				$Cmdlet
			)

			begin {
				#region Worker Code
				$code = {
					param (
						$TargetPath
					)

					$PSDefaultParameterValues['Write-PSFMessage:ModuleName'] = 'PSFramework.NuGet'
					$PSDefaultParameterValues['Write-PSFMessage:FunctionName'] = 'Publish-StagingModule'

					trap {
						Write-PSFMessage -Level Error -String 'Publish-StagingModule.Error.General' -StringValues $TargetPath.ComputerName -ErrorRecord $_
						$__PSF_Workflow.Data.Failed[$TargetPath.ComputerName] = $true
						$__PSF_Workflow.Data.Completed[$TargetPath.ComputerName] = $true
						$null = $__PSF_Workflow.Data.InProgress.TryRemove($TargetPath.ComputerName, [ref]$null)
						return
					}

					$publishCommon = @{
						ComputerName = $env:COMPUTERNAME
					}
					$oldSuffix = "old_$(Get-Random -Minimum 100 -Maximum 999)"
					throw "Not Refitted to work remotely yet!"
		
					foreach ($module in Get-ChildItem -Path $Path) {
						foreach ($version in Get-ChildItem -Path $module.FullName) {
							foreach ($destination in $TargetPath.Results) {
								if (-not $destination.Exists) { continue }
		
								$publishCommon.Path = $destination.Path
								$publishCommon.Module = $module.Name
								$publishCommon.Version = $version.Name
		
								$testPath = Join-Path -Path $destination.Path -ChildPath "$($module.Name)/$($version.Name)/$($module.DirectoryName).psd1"
								$alreadyExists = Invoke-Command -Session $TargetPath.Session.Session -ScriptBlock {
									Test-Path -Path $using:testPath
								}

								if ($alreadyExists -and -not $Force) {
									Write-PSFMessage -String 'Publish-StagingModule.Skipping.AlreadyExists' -StringValues $module.Name, $version.Name
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
								Invoke-PSFProtectedCommand -ActionString 'Publish-StagingModule.Deploying.Local' -ActionStringValues $module.Name, $version.Name -Target $TargetPath -ScriptBlock {
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
				#endregion Worker Code

				# Limit Worker Count to Target Count
				if ($TargetPath.Count -lt $ThrottleLimit) { $ThrottleLimit = $TargetPath.Count }

				$workflow = New-PSFRunspaceWorkflow -Name PublishModule -Force
				$workflow | Add-PSFRunspaceWorker -Name Publisher -InQueue Input -OutQueue Results -ScriptBlock $code -CloseOutQueue -Count $ThrottleLimit -Functions @{
					'New-PublishResult' = [scriptblock]::Create((Get-Command New-PublishResult).Definition)
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
					$results = $workflow | Read-PSFRunspaceQueue -Name Results -All
					$workflow | Remove-PSFRunspaceWorkflow
					Enable-PSFConsoleInterrupt
					$results
				}
			}
		}
		#endregion Utility Functions
	}
	process {
		$localPaths = @($TargetPath).Where{ -not $_.Session }[0]
		$remotePaths = @($TargetPath).Where{ $_.Session }

		if ($localPaths) {
			Publish-StagingModuleLocal -Path $Path -TargetPath $localPaths -Force:$Force -Cmdlet $Cmdlet
		}
		if ($remotePaths) {
			Publish-StagingModuleRemote -Path $Path -TargetPath $remotePaths -ThrottleLimit $ThrottleLimit -Force:$Force -Cmdlet $Cmdlet
		}
	}
}