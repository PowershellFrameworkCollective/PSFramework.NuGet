function Publish-ModuleV2 {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		$Module,

		$Repository,

		[string]
		$ApiKey,

		[PSCredential]
		$Credential,

		[switch]
		$SkipDependenciesCheck,

		[switch]
		$Continue,

		[string]
		$ContinueLabel,

		$Cmdlet = $PSCmdlet
	)
	process {
		$killIt = $ErrorActionPreference -eq 'Stop'
		
		$commonPublish = @{
			Repository = $Repository.Name
			Confirm = $false
		}
		if ($Repository.Credential) { $commonPublish.Credential = $Credential }
		if ($Credential) { $commonPublish.Credential = $Credential }
		if ($ApiKey) { $commonPublish.NuGetApiKey = $ApiKey }

		if ($SkipDependenciesCheck) {
			Disable-ModuleCommand -Name 'Get-ModuleDependencies' -ModuleName 'PowerShellGet'

			$customReturn = Get-Module $Module.Path -ListAvailable
			Disable-ModuleCommand -Name 'Microsoft.PowerShell.Core\Test-ModuleManifest' -ModuleName 'PowerShellGet' -Return $customReturn
		}

		try {
			Invoke-PSFProtectedCommand -ActionString 'Publish-ModuleV2.Publish' -ActionStringValues $Module.Name, $Module.Version, $Repository -ScriptBlock {
				Publish-Module @commonPublish -Path $Module.Path -ErrorAction Stop
			} -Target "$($Module.Name) ($($Module.Version))" -PSCmdlet $Cmdlet -EnableException $killIt -Continue:$Continue -ContinueLabel $ContinueLabel
		}
		finally {
			if ($SkipDependenciesCheck) {
				Enable-ModuleCommand -Name 'Get-ModuleDependencies' -ModuleName 'PowerShellGet'
				Enable-ModuleCommand -Name 'Microsoft.PowerShell.Core\Test-ModuleManifest' -ModuleName 'PowerShellGet'
			}
		}
	}
}