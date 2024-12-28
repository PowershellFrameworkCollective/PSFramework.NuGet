function Get-PSFModuleScope {
	<#
	.SYNOPSIS
		Lists the registered module scopes.
	
	.DESCRIPTION
		Lists the registered module scopes.
		These are used as presets with Install-PSFModule's '-Scope' parameter.

		Use Register-PSFModuleScope to add additional scopes.
	
	.PARAMETER Name
		The name of the scope to filter by.
		Defaults to '*'
	
	.EXAMPLE
		PS C:\> Get-PSFModuleScope
		
		Lists all registered module scopes.
	#>
	[CmdletBinding()]
	param (
		[PsfArgumentCompleter('PSFramework.NuGet.ModuleScope')]
		[string]
		$Name = '*'
	)
	process {
		($script:moduleScopes.Values) | Where-Object Name -Like $Name
	}
}