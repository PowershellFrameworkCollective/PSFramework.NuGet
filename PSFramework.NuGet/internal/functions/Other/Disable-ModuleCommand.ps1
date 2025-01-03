function Disable-ModuleCommand {
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