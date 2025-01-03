function Publish-PSFResourceModule {
	<#
	.SYNOPSIS
		Publishes a pseudo-module, the purpose of which is to transport arbitrary files & folders.
	
	.DESCRIPTION
		Publishes a pseudo-module, the purpose of which is to transport arbitrary files & folders.
		This allows using nuget repositories to distribute arbitrary files, not bound to its direct PowerShell
		use as "Publish-PSFModule" would enforce.

		For example, with this, a templating engine could offer commands such as:
		- Publish-Template
		- Install-Template
		- Update-Template
	
	.PARAMETER Name
		Name of the module to create.
	
	.PARAMETER Version
		Version of the module to create.
		Defaults to "1.0.0".
	
	.PARAMETER Path
		Path to the files and folders to include.
	
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
	
	.PARAMETER RequiredModules
		The modules your resource module requires.
		These dependencies will be treated as Resoource modules as well, not regular modules.
	
	.PARAMETER Description
		Description of your resource module.
		Will be shown in repository services hosting it.
	
	.PARAMETER Author
		The author of your resource module.
		Defaults to your user name.
	
	.PARAMETER Tags
		Tags to include in your resource module.
	
	.PARAMETER LicenseUri
		Link to the license governing your resource module.
	
	.PARAMETER IconUri
		Link to the icon to present in the PSGallery.
	
	.PARAMETER ProjectUri
		Link to the project your resources originate from.
		Used in the PSGallery to guide visitors to more information.
	
	.PARAMETER ReleaseNotes
		Release notes for your resource module.
		Or at least a link to them.
	
	.PARAMETER Prerelease
		The prerelease flag to tag your resource module under.
		This allows hiding it from most users.
	
	.EXAMPLE
		PS C:\> Publish-PSFResourceModule -Name Psmd.Template.MyFunction -Version 1.1.0 -Path .\MyFunction\* -Repository PSGallery -ApiKey $key
		
		Publishes all files under the MyFunction folder to the PSGallery.
		The resource module will be named "Psmd.Template.MyFunction" and versioned as '1.1.0'
	#>
	[CmdletBinding(DefaultParameterSetName = 'ToRepository')]
	Param (
		[PsfValidateScript('PSFramework.Validate.SafeName', ErrorString = 'PSFramework.Validate.SafeName')]
		[string]
		$Name,

		[string]
		$Version = '1.0.0',

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

		[object[]]
		$RequiredModules,

		[string]
		$Description = '<Dummy Description>',

		[string]
		$Author,

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
		$killIt = $ErrorActionPreference -eq 'Stop'
		$stagingDirectory = New-PSFTempDirectory -ModuleName 'PSFramework.NuGet' -Name Publish.ResourceModule -DirectoryName $Name
		$publishParam = $PSBoundParameters | ConvertTo-PSFHashtable -ReferenceCommand Publish-PSFModule -Exclude Path, ErrorAction
	}
	process {
		try {
			New-DummyModule -Path $stagingDirectory -Name $Name -Version $Version -RequiredModules $RequiredModules -Description $Description -Author $Author -Cmdlet $PSCmdlet
			$resources = New-Item -Path $stagingDirectory -Name Resources -ItemType Directory -Force
			$Path | Copy-Item -Destination $resources.FullName -Recurse -Force -Confirm:$false -WhatIf:$false

			Publish-PSFModule @publishParam -Path $stagingDirectory -ErrorAction Stop
		}
		catch {
			Stop-PSFFunction -String 'Publish-PSFResourceModule.Error' -StringValues $Name -EnableException $killIt -ErrorRecord $_ -Cmdlet $PSCmdlet
			return
		}
		finally {
			Remove-PSFTempItem -ModuleName 'PSFramework.NuGet' -Name Publish.ResourceModule
		}
	}
}
