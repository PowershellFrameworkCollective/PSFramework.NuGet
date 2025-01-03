function Publish-PSFModule {
	<#
	.SYNOPSIS
		Publish a PowerShell module.
	
	.DESCRIPTION
		Publish a PowerShell module.
		Allows publishing to either nuget repositories or as .nupkg file to disk.
	
	.PARAMETER Path
		The path to the module to publish.
		Either the directory or the psd1 file.
	
	.PARAMETER Repository
		The repository to publish to.
	
	.PARAMETER Type
		What kind of repository to publish to.
		- All (default): All types of repositories are eligible.
		- V2: Only repositories from the old PowerShellGet are eligible.
		- V3: Only repositories from the new PSResourceGet are eligible.
		If multiple repositories of the same name are found, the one at the highest version among them is chosen.
	
	.PARAMETER Credential
		The credentials to use to authenticate to the Nuget service.
		Mostly used for internal repository servers.
	
	.PARAMETER ApiKey
		The ApiKey to use to authenticate to the Nuget service.
		Mostly used for publishing to the PSGallery.
	
	.PARAMETER SkipDependenciesCheck
		Do not validate dependencies or the module manifest.
		This removes the need to have the dependencies installed when publishing using PSGet v2
	
	.PARAMETER DestinationPath
		Rather than publish to a repository, place the finished .nupgk file in this path.
		Use when doing the final publish step outside of PowerShell code.
	
	.PARAMETER Tags
		Tags to add to the module.
	
	.PARAMETER LicenseUri
		The LicenseUri for the module.
		Mostly used as metadata for the PSGallery.
	
	.PARAMETER IconUri
		The Icon Uri for the module.
		Mostly used as metadata for the PSGallery.
	
	.PARAMETER ProjectUri
		The Link to the project - frequently the Github repository hosting your module.
		Mostly used as metadata for the PSGallery.
	
	.PARAMETER ReleaseNotes
		The release notes of your module - or at least the link to them.
		Mostly used as metadata for the PSGallery.
	
	.PARAMETER Prerelease
		The prerelease tag to include.
		This flags the module as "Prerelease", hiding it from regular Find-PSFModule / Install-PSFModule use.
		Use to provide test versions that only affect those in the know.
	
	.EXAMPLE
		PS C:\> Publish-PSFModule -Path C:\code\MyModule -Repository PSGallery -ApiKey $key

		Publishes the module "MyModule" to the PSGallery.

	.EXAMPLE
		PS C:\> Publish-PSFModule -Path C:\code\MyModule -Repository AzDevOps -Credential $cred -SkipDependenciesCheck

		Publishes the module "MyModule" to the repository "AzDevOps".
		It will not check for any dependencies and use the credentials stored in $cred to authenticate the request.

	.EXAMPLE
		PS C:\> Publish-PSFModule -Path C:\code\MyModule -Repository AzDevOps -SkipDependenciesCheck

		Publishes the module "MyModule" to the repository "AzDevOps".
		It will not check for any dependencies.
		If there are any credentials assigned to the repository (Use Set-PSFRepository to assign), those will be used to authenticate the request.
		Otherwise it will try default windows authentication (Which may well work, if the repository is hosted by an on-prem Azure DevOps Server in an Active Directory environment).

	.EXAMPLE
		PS C:\> Publish-PSFModule -Path C:\code\MyModule -DestinationPath \\contoso.com\it\packages

		Wraps the module "MyModule" into a .nupkg file and copies that to '\\contoso.com\it\packages'
	#>
	[CmdletBinding(DefaultParameterSetName = 'ToRepository', SupportsShouldProcess = $true)]
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
		$ProjectUri,

		[string]
		$ReleaseNotes,

		[string]
		$Prerelease
	)
	
	begin {
		#region Setup
		$killIt = $ErrorActionPreference -eq 'Stop'
		if ($Repository) {
			# Resolve Repositories
			Search-PSFPowerShellGet
			$repositories = Resolve-Repository -Name $Repository -Type $Type -Cmdlet $PSCmdlet | Group-Object Name | ForEach-Object {
				@($_.Group | Sort-Object Type -Descending)[0]
			}
		}
		# Create Temp Directories
		$workingDirectory = New-PSFTempDirectory -ModuleName PSFramework.NuGet -Name Publish.Work

		$commonPublish = @{
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
				Update-PSFModuleManifest -Path $moduleData.ManifestPath -Tags $Tags -LicenseUri $LicenseUri -IconUri $IconUri -ProjectUri $ProjectUri -ReleaseNotes $ReleaseNotes -Prerelease $Prerelease -Cmdlet $PSCmdlet -Continue

				# Case 1: Publish to Destination Path
				if ($DestinationPath) {
					Publish-ModuleToPath -Module $moduleData -Path $DestinationPath -Cmdlet $PSCmdlet
					continue
				}

				# Case 2: Publish to Repository
				:repo foreach ($repositoryObject in $repositories) {
					switch ($repositoryObject.Type) {
						V2 {
							Publish-ModuleV2 @commonPublish -Module $moduleData -Repository $repositoryObject 
						}
						V3 {
							Publish-ModuleV3 @commonPublish -Module $moduleData -Repository $repositoryObject 
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