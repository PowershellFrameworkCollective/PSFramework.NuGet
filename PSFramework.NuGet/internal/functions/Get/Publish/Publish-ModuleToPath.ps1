function Publish-ModuleToPath {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		$Module,

		[string]
		$Path,

		[switch]
		$ForceV3,

		$Cmdlet = $PSCmdlet
	)
	begin {
		$killIt = $ErrorActionPreference -eq 'Stop'
		$useV3 = $script:psget.V3 -or $ForceV3
		if (-not $useV3) {
			Assert-V2Publishing -Cmdlet $Cmdlet
		}
		$stagingDirectory = New-PSFTempDirectory -ModuleName PSFramework.NuGet -Name Publish.StagingLocalCopy
	}
	process {
		#region Verify Existing Module in Repository
		$fileName = '{0}.{1}.nupkg' -f $Module.Name, $Module.Version
		$destinationFile = Join-Path -Path $Path -ChildPath $fileName

		if (Test-Path -Path $destinationFile) {
			Stop-PSFFunction -String 'Publish-ModuleToPath.Error.AlreadyPublished' -StringValues $Module.Name, $Module.Version, $Path -EnableException $killIt -Category InvalidOperation
			return
		}
		#endregion Verify Existing Module in Repository

		$repoName = "PSF_Temp_$(Get-Random)"
		#region V3
		if ($useV3) {
			try {
				Register-PSResourceRepository -Name $repoName -Uri $stagingDirectory -Trusted
				Publish-PSResource -Path $Module.Path -Repository $repoName -SkipDependenciesCheck
			}
			catch {
				Stop-PSFFunction -String 'Publish-ModuleToPath.Error.FailedToStaging.V3' -StringValues $module.Name, $module.Version -Cmdlet $Cmdlet -ErrorRecord $_ -EnableException $killIt
				return
			}
			finally {
				Unregister-PSResourceRepository -Name $repoName
			}
		}
		#endregion V3

		#region V2
		else {
			try {
				Register-PSRepository -Name $repoName -SourceLocation $stagingDirectory -PublishLocation $stagingDirectory -InstallationPolicy Trusted
				Disable-ModuleCommand -Name 'Get-ModuleDependencies' -ModuleName 'PowerShellGet'
				Publish-Module -Path $Module.Path -Repository $repoName
			}
			catch {
				Stop-PSFFunction -String 'Publish-ModuleToPath.Error.FailedToStaging.V2' -StringValues $module.Name, $module.Version -Cmdlet $Cmdlet -ErrorRecord $_ -EnableException $killIt
				return
			}
			finally {
				Enable-ModuleCommand -Name 'Get-ModuleDependencies' -ModuleName 'PowerShellGet'
				Unregister-PSRepository -Name $repoName
			}
		}
		#endregion V2
	
		#region Copy New Package
		$sourcePath = Join-Path -Path $stagingDirectory -ChildPath $fileName
		Invoke-PSFProtectedCommand -ActionString 'Publish-ModuleToPath.Publishing' -ActionStringValues $module.Name, $module.Version -Target $Path -ScriptBlock {
			Copy-Item -Path $sourcePath -Destination $Path -Force -ErrorAction Stop -Confirm:$false
		} -PSCmdlet $Cmdlet -EnableException $killIt
		#endregion Copy New Package
	}
	end {
		Remove-PSFTempItem -ModuleName PSFramework.NuGet -Name Publish.StagingLocalCopy
	}
}