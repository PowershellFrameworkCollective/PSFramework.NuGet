function Publish-ModuleV2 {
	<#
	.SYNOPSIS
		Publishes a PowerShell module using PowerShellGet V2.
	
	.DESCRIPTION
		Publishes a PowerShell module using PowerShellGet V2.
	
	.PARAMETER Module
		The module to publish.
		Expects an module information object as returned by Copy-Module.
	
	.PARAMETER Repository
		The repository to publish to.
		Expects a repository object as returned by Get-PSFRepository.
	
	.PARAMETER ApiKey
		The ApiKey for authenticating the request.
		Generally needed when publishing to the PowerShell gallery.
	
	.PARAMETER Credential
		The credentials to use for authenticating the request.
		Generally needed when publishing to internal repositories.
	
	.PARAMETER SkipDependenciesCheck
		Do not check for required modules, do not validate the module manifest.
		By default, it will check, whether all required modules are already published to the repository.
		However, it also - usually - requires all modules to be locally available when publishing.
		With this parameter set, that is no longer an issue.
	
	.PARAMETER Continue
		In case of error, call continue unless ErrorAction is set to Stop.
		Simplifies error handling in non-terminating situations.
	
	.PARAMETER ContinueLabel
		When used together with "-Contionue", it allowd you to specify the label/name of the loop to continue with.
	
	.PARAMETER Cmdlet
		The PSCmdlet variable of the calling command, used to ensure errors happen within the scope of the caller, hiding this internal helper command from the user.

	.PARAMETER WhatIf
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
	
	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

	.EXAMPLE
		PS C:\> Publish-ModuleV2 -Module $module -Repository $repo -SkipDependenciesCheck -ApiKey $key
	
		Publishes the module provided in $module to the repository $repo, authenticating the request with the Api key $key.
		It will not validate any dependencies as it does so.
	#>
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