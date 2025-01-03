function Disable-ModuleCommand {
	<#
	.SYNOPSIS
		Disables a specific command in a specific module.
	
	.DESCRIPTION
		Disables a specific command in a specific module.
		This hides the command with an alias pointing to a mostly empty function that cares not about the parameters provided.

		Use "Enable-ModuleCommand" to revert the changes applied.
	
	.PARAMETER Name
		The name of the command to hide.
	
	.PARAMETER ModuleName
		The module the command to hide is from
	
	.PARAMETER Return
		The object the command should return when called.
		By default, nothing is returned.
	
	.EXAMPLE
		PS C:\> Disable-ModuleCommand -Name 'Get-ModuleDependencies' -ModuleName 'PowerShellGet'

		Prevents the command Get-ModuleDependencies from PowerShellGet from returning anything.

	.EXAMPLE
		PS C:\> Disable-ModuleCommand -Name 'Microsoft.PowerShell.Core\Test-ModuleManifest' -ModuleName 'PowerShellGet' -Return $customReturn

		Prevents the command Microsoft.PowerShell.Core\Test-ModuleManifest from doing its usual job.
		Instead it will statically return the value in $customReturn.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Name,

		[Parameter(Mandatory = $true)]
		[string]
		$ModuleName,

		$Return
	)
	process {
		if ($PSBoundParameters.Keys -contains 'Return') {
			$script:ModuleCommandReturns[$Name] = $Return
		}


		Import-Module $ModuleName -Verbose:$False
		& (Get-Module $ModuleName) {
			function script:psfFunctionOverride {
				$calledAs = $MyInvocation.InvocationName
				$returns = & (Get-Module PSFramework.NuGet) { $script:ModuleCommandReturns }
				if ($returns.Keys -contains $calledAs) {
					$returns[$calledAs]
				}
			}
			Set-Alias -Name $args[0] -Value psfFunctionOverride -Scope Script
		} $Name
	}
}