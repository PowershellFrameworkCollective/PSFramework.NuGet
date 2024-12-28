function Register-PSFModuleScope {
	<#
	.SYNOPSIS
		Provide a scope you can install modules to.
	
	.DESCRIPTION
		Provide a scope you can install modules to.
		Those are used by Install-PFModule to pick what path to install to.
	
	.PARAMETER Name
		Name of the scope.
		Must be unique, otherwise it will overwrite an existing scope.
	
	.PARAMETER Path
		Path where modules should be stored.

	.PARAMETER Mode
		Specifying a mode will add the path provided to the PSModulePath variable for this session.
		- Append: Adds the path as the last option, making it the last location PowerShell will look for modules.
		- Prepend: Adds the path as the first option, making it take precedence over all other module paths.
	
	.PARAMETER ScriptBlock
		Logic determining, where modules should be stored.
		This scriptblock will not receive any parameters.
		Used to dynamically determine the path, may be executed against remote computers,
		when installing to remote computers.
		Keep in mind that dependencies may not be available.
	
	.PARAMETER Description
		A description to add to the module scope registered.
		Purely for documentation purposes.
	
	.EXAMPLE
		PS C:\> Register-PSFModuleScope -Name WinPSAllUsers -Path 'C:\Program Files\WindowsPowerShell\Modules'
		
		Registers the module-scope "WinPSAllusers" with the default path for Modules in Windows PowerShell.
		This would allow installing modules for Windows PowerShell from PowerShell 7.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Name,

		[Parameter(Mandatory = $true, ParameterSetName = 'Path')]
		[string]
		$Path,

		[Parameter(ParameterSetName = 'Path')]
		[ValidateSet('Append', 'Prepend')]
		[string]
		$Mode,

		[Parameter(Mandatory = $true, ParameterSetName = 'Scriptblock')]
		[PsfValidateLanguageMode('FullLanguage')]
		[scriptblock]
		$ScriptBlock,

		[string]
		$Description
	)
	process {
		$typeMap = @{
			$true  = 'Dynamic'
			$false = 'Static'
		}
		$script:moduleScopes[$Name] = [PSCustomObject]@{
			PSTypeName  = 'PSFramework.NuGet.ModulePath'
			Name        = $Name
			Type        = $typeMap[($ScriptBlock -as [bool])]
			Path        = $Path
			ScriptBlock = $ScriptBlock
			Description = $Description
		}
		if (-not $Mode) { return }

		$envPaths = $env:PSModulePath -split ';'
		if ($Path -in $envPaths) { return }
		switch ($Mode) {
			'Append' {
				$envPaths = @($envPaths) + $Path
			}
			'Prepend' {
				$envPaths = @($Path) + $envPaths
			}
		}
		$env:PSModulePath = $envPaths -join ';'
	}
}