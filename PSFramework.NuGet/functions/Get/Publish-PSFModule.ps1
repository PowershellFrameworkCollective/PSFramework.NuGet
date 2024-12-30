function Publish-PSFModule
{
	[CmdletBinding(DefaultParameterSetName = 'ToRepository')]
	Param (
		[Parameter(Mandatory = $true)]
		[PsfPath]
		$Path,

		[Parameter(Mandatory = $true, ParameterSetName = 'ToRepository')]
		[PsfValidateSet(TabCompletion = 'PSFramework.NuGet.Repository')]
		[PsfArgumentCompleter('PSFramework.NuGet.Repository')]
		[string[]]
		$Repository,

		[Parameter(ParameterSetName = 'ToRepository')]
		[ValidateSet('All', 'V2', 'V3')]
		[string]
		$Type = 'All',

		[Parameter(ParameterSetName = 'ToRepository')]
		[PSCredential]
		$Credential,

		[Parameter(ParameterSetName = 'ToRepository')]
		[string]
		$ApiKey,

		[Parameter(Mandatory = $true, ParameterSetName = 'ToPath')]
		[PsfDirectory]
		$DestinationPath,

		[switch]
		$SkipDependenciesCheck,

		[string[]]
		$Tags,

		[string]
		$LicenseUri,

		[string]
		$IconUri,

		[string]
		$ProjectUri
	)
	
	begin
	{
	}
	process
	{
		#TODO: Implement
	}
}
<#
- Path
- DestinationPath (-/V3)

- Repository
- Type
- Credential
- ApiKey

- SkipAutopmaticTags (V2/-) - Disregard
- Force (V2/-) - Disregard
- SkipDependenciesCheck (-/V3) - Partial (only for V3, as V2 does not support)
- SkipModuleManifestValidate (-/V3) - Always. Cheat to make V2 work out.

# Will be implemented outside of the Get Commands
- Tags (V2/-)
- LicenseUri (V2/-)
- IconUri (V2/-)
- ProjectUri (V2/-)
#>