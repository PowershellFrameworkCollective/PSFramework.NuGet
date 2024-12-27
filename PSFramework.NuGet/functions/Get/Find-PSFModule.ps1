function Find-PSFModule {
	<#
	.SYNOPSIS
		Search for modules in PowerShell repositories.
	
	.DESCRIPTION
		Search for modules in PowerShell repositories.
	
	.PARAMETER Name
		Name(s) of the module(s) to look for.
	
	.PARAMETER Repository
		The repositories to search in.
	
	.PARAMETER Tag
		Tags to search by.
	
	.PARAMETER Credential
		Credentials to use to access repositories.
	
	.PARAMETER AllowPrerelease
		Whether to include modules flagged as "Prerelease" as part of the results
	
	.PARAMETER IncludeDependencies
		Whether to also list all required dependencies.
	
	.PARAMETER Version
		Version constrains for the module to search.
		Will use the latest version available within the limits.
		Examples:
		- "1.0.0": EXACTLY this one version
		- "1.0.0-1.999.999": Any version between the two limits (including the limit values)
		- "[1.0.0-2.0.0)": Any version greater or equal to 1.0.0 but less than 2.0.0
		- "2.3.0-": Any version greater or equal to 2.3.0.

		Supported Syntax:
		<Prefix><Version><Connector><Version><Suffix>

		Prefix: "[" (-ge) or "(" (-gt) or nothing (-ge)
		Version: A valid version of 2-4 elements or nothing
		Connector: A "," or a "-"
		Suffix: "]" (-le) or ")" (-lt) or nothing (-le)
	
	.PARAMETER AllVersions
		Whether all versions available should be returned together
	
	.PARAMETER Type
		What kind of repository to search in.
		+ All: (default) Use all, irrespective of type
		+ V2: Only search classic repositories, as would be returned by Get-PSRepository
		+ V3: Only search modern repositories, as would be returned by Get-PSResourceRepository
	
	.EXAMPLE
		PS C:\> Find-PSFModule -Name PSFramework

		Search all configured repositories for the module "PSFramework"
	#>
	[CmdletBinding(DefaultParameterSetName = 'default')]
	Param (
		[Parameter(Position = 0)]
		[string[]]
		$Name,

		[PsfArgumentCompleter('PSFramework.NuGet.Repository')]
		[Parameter(Position = 1)]
		[string[]]
		$Repository,

		[string[]]
		$Tag,

		[PSCredential]
		$Credential,

		[switch]
		$AllowPrerelease,

		[switch]
		$IncludeDependencies,

		[Parameter(ParameterSetName = 'Version')]
		[string]
		$Version,

		[Parameter(ParameterSetName = 'AllVersions')]
		[switch]
		$AllVersions,

		[ValidateSet('All', 'V2', 'V3')]
		[string]
		$Type = 'All'
	)
	
	begin {
		#region Functions
		function ConvertFrom-ModuleInfo {
			[CmdletBinding()]
			param (
				[Parameter(ValueFromPipeline = $true)]
				$InputObject
			)

			process {
				if ($null -eq $InputObject) { return }
				$type = 'V2'
				if ($InputObject.GetType().Name -eq 'PSResourceInfo') { $type = 'V3' }

				[PSCustomObject]@{
					PSTypeName = 'PSFramework.NuGet.ModuleInfo'
					Name       = $InputObject.Name
					Version    = $InputObject.Version
					Type       = $type
					Repository = $InputObject.Repository
					Author     = $InputObject.Author
					Commands   = $InputObject.Includes.Command
					Object     = $InputObject
				}
			}
		}
		#endregion Functions

		$useVersionFilter = $Version -or $AllVersions
		if ($Version) {
			$convertedVersion = Read-VersionString -Version $Version -Cmdlet $PSCmdlet
			$versionFilter = $convertedVersion.V3String
		}
		if ($PSCmdlet.ParameterSetName -eq 'AllVersions') {
			$versionFilter = '*'
		}

		$param = $PSBoundParameters | ConvertTo-PSFHashtable -Include Name, Repository, Tag, Credential, IncludeDependencies
	}
	process {
		#region V2
		if ($script:psget.V2 -and $Type -in 'All', 'V2') {
			$paramClone = $param.Clone()
			$paramClone += $PSBoundParameters | ConvertTo-PSFHashtable -Include AllVersions, AllowPrerelease
			if ($Version) {
				if ($convertedVersion.Required) { $paramClone.RequiredVersion = $convertedVersion.Required }
				if ($convertedVersion.Minimum) { $paramClone.MinimumVersion = $convertedVersion.Minimum }
				if ($convertedVersion.Maximum) { $paramClone.MaximumVersion = $convertedVersion.Maximum }
			}
			$execute = $true
			if ($paramClone.Repository) {
				$paramClone.Repository = $paramClone.Repository | Where-Object {
					$_ -match '\*' -or
					$_ -in (Get-PSFRepository -Type V2).Name
				}
				$execute = $paramClone.Repository -as [bool]
			}

			if ($execute) {
				Find-Module @paramClone | ConvertFrom-ModuleInfo
			}
		}
		#endregion V2

		#region V3
		if ($script:psget.V3 -and $Type -in 'All', 'V3') {
			$paramClone = $param.Clone()
			$paramClone += $PSBoundParameters | ConvertTo-PSFHashtable -Include AllowPrerelease -Remap @{
				AllowPrerelease = 'Prerelease'
			}
			if ($useVersionFilter) {
				$paramClone.Version = $versionFilter
			}
			$paramClone.Type = 'Module'
			$execute = $true
			if ($paramClone.Repository) {
				$paramClone.Repository = $paramClone.Repository | Where-Object {
					$_ -match '\*' -or
					$_ -in (Get-PSFRepository -Type V3).Name
				}
				$execute = $paramClone.Repository -as [bool]
			}
			if ($execute) {
				Find-PSResource @paramClone | ConvertFrom-ModuleInfo
			}
		}
		#endregion V3
	}
}