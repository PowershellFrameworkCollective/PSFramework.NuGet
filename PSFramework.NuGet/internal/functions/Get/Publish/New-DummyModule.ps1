function New-DummyModule {
	<#
	.SYNOPSIS
		Creates an empty dummy module.
	
	.DESCRIPTION
		Creates an empty dummy module.
		This is used for publishing Resource Modules, the purpose of which are the files later copied into it and not its nature as a module.
	
	.PARAMETER Path
		Where to create the dummy module.
	
	.PARAMETER Name
		The name of the module to assign.
	
	.PARAMETER Version
		What version should the module have?
		Defaults to: 1.0.0
	
	.PARAMETER Description
		A description to include in the dummy module.
		Defaults to a pointless placeholder.
	
	.PARAMETER Author
		Who is the author?
		Defaults to the current user's username.
	
	.PARAMETER RequiredModules
		Any dependencies to include.
		Uses the default module-spec syntax.
	
	.PARAMETER Cmdlet
		The PSCmdlet variable of the calling command, used to ensure errors happen within the scope of the caller, hiding this internal helper command from the user.
	
	.EXAMPLE
		PS C:\> New-DummyModule -Path $stagingDirectory -Name $Name -Version $Version -RequiredModules $RequiredModules -Description $Description -Author $Author -Cmdlet $PSCmdlet

		Creates a new dummy module in $stagingDirectory
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Path,

		[Parameter(Mandatory = $true)]
		[string]
		$Name,

		[string]
		$Version = '1.0.0',

		[string]
		$Description = '<Dummy Description>',

		[AllowEmptyString()]
		[string]
		$Author,

		[object[]]
		$RequiredModules
	)
	process {
		$param = @{
			Path = Join-Path -Path $Path -ChildPath "$Name.psd1"
			RootModule = "$Name.psm1"
			ModuleVersion = $Version
			Description = $Description
		}
		if ($Author) { $param.Author = $Author }
		if ($RequiredModules) { $param.RequiredModules = $RequiredModules }

		New-ModuleManifest @param
		$null = New-Item -Path $Path -Name "$Name.psm1" -ItemType File
	}
}