function Publish-PSFModule {
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

		[Parameter(ParameterSetName = 'ToRepository')]
		[switch]
		$SkipDependenciesCheck,

		[Parameter(Mandatory = $true, ParameterSetName = 'ToPath')]
		[PsfDirectory]
		$DestinationPath,

		[string[]]
		$Tags,

		[string]
		$LicenseUri,

		[string]
		$IconUri,

		[string]
		$ProjectUri
	)
	
	begin {
		#region Setup
		$killIt = $ErrorActionPreference = 'Stop'
		if ($Repository) {
			# Resolve Repositories
			Search-PSFPowerShellGet
			$repositories = Resolve-Repository -Name $Repository -Type $Type -Cmdlet $PSCmdlet | Group-Object Name | ForEach-Object {
				@($_.Group | Sort-Object Type -Descending)[0]
			}
		}
		# Create Temp Directories
		$workingDirectory = New-PSFTempDirectory -ModuleName PSFramework.NuGet -Name Publish.Work
		$stagingDirectory = New-PSFTempDirectory -ModuleName PSFramework.NuGet -Name Publish.Staging

		$commonPublish = @{
			StagingDirectory = $stagingDirectory
			Cmdlet           = $PSCmdlet
			Continue         = $true
			ContinueLabel    = 'repo'
		}
		if ($ApiKey) { $commonPublish.ApiKey = $ApiKey }
		if ($Credential) { $commonPublish.Credential = $Credential }
		if ($SkipDependenciesCheck) { $commonPublish.SkipDependenciesCheck = $SkipDependenciesCheck }
		#endregion Setup
	}
	process {
		try {
			foreach ($sourceModule in $Path) {
				# Update Metadata per Parameter
				$moduleData = Copy-Module -Path $sourceModule -Destination $workingDirectory -Cmdlet $PSCmdlet -Continue
				Update-ModuleInformation -Module $moduleData -Tags $Tags -LicenseUri $LicenseUri -IconUri $IconUri -ProjectUri $ProjectUri -Cmdlet $PSCmdlet -Continue

				# Case 1: Publish to Destination Path
				if ($DestinationPath) {
					Publish-ModuleToPath -Module $moduleData -Path $DestinationPath -Cmdlet $PSCmdlet
					continue
				}

				# Case 2: Publish to Repository
				:repo foreach ($repositoryObject in $repositories) {
					switch ($repositoryObject.Type) {
						V2 {
							Publish-ModuleV2 @commonPublish -Module $moduleData -Repository $repositoryObject.Name 
						}
						V3 {
							Publish-ModuleV3 @commonPublish -Module $moduleData -Repository $repositoryObject.Name 
						}
						default {
							Stop-PSFFunction -String 'Publish-PSFModule.Error.UnexpectedRepositoryType' -StringValues $repositoryObject.Name, $repositoryObject.Type -Continue -Cmdlet $PSCmdlet -EnableException $killIt
						}
					}
				}
			}
		}
		finally {
			# Cleanup Temp Directory
			Remove-PSFTempItem -ModuleName PSFramework.NuGet -Name Publish.*
		}
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