function Disable-ModuleCommand {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Name,

		[Parameter(Mandatory = $true)]
		[string]
		$ModuleName
	)
	process {
		Import-Module $ModuleName
		& (Get-Module $ModuleName) {
			function script:psfFunctionOverride { }
			Set-Alias -Name $args[0] -Value psfFunctionOverride -Scope Script
		} $Name
	}
}