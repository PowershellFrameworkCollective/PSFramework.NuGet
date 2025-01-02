function Publish-ModuleV3 {
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
		<#
		TODO:
		+ Implement SkipModuleManifestValidate?
		+ Test Publish to local with & without dependencies
		#>
		$killIt = $ErrorActionPreference -eq 'Stop'
		$commonPublish = @{
			Repository = $Repository.Name
			Confirm = $false
		}
		if ($Repository.Credential) { $commonPublish.Credential = $Credential }
		if ($Credential) { $commonPublish.Credential = $Credential }
		if ($ApiKey) { $commonPublish.ApiKey = $ApiKey }
		if ($SkipDependenciesCheck) { $commonPublish.SkipDependenciesCheck = $SkipDependenciesCheck }

		Invoke-PSFProtectedCommand -ActionString 'Publish-ModuleV3.Publish' -ActionStringValues $Module.Name, $Module.Version, $Repository -ScriptBlock {
			Publish-PSResource @commonPublish -Path $Module.Path -ErrorAction Stop
		} -Target "$($Module.Name) ($($Module.Version))" -PSCmdlet $Cmdlet -EnableException $killIt -Continue:$Continue -ContinueLabel $ContinueLabel
	}
}