function Publish-PSFResourceModule {
	[CmdletBinding()]
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
