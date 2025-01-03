function New-DummyModule {
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
		$RequiredModules,

		$Cmdlet = $PSCmdlet
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