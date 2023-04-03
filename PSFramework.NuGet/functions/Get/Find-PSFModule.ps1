function Find-PSFModule {
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

		[Parameter(ParameterSetName = 'VersionRange')]
		[version]
		$MinimumVersion,

		[Parameter(ParameterSetName = 'VersionRange')]
		[version]
		$MaximumVersion,

		[Parameter(ParameterSetName = 'RequiredVersion')]
		[version]
		$RequiredVersion,

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

		$useVersionFilter = $MinimumVersion -or $MaximumVersion -or $RequiredVersion -or $AllVersions
		switch ($PSCmdlet.ParameterSetName) {
			'VersionRange' { $versionFilter = '[{0}, {1}]' -f $MinimumVersion, $MaximumVersion }
			'RequiredVersion' { $versionFilter = "$RequiredVersion" }
			'AllVersions' { $versionFilter = '*' }
		}

		$param = $PSBoundParameters | ConvertTo-PSFHashtable -Include Name, Repository, Tag, Credential, IncludeDependencies
	}
	process {
		#region V2
		if ($script:psget.V2 -and $Type -in 'All', 'V2') {
			$paramClone = $param.Clone()
			$paramClone += $PSBoundParameters | ConvertTo-PSFHashtable -Include MinimumVersion, MaximumVersion, RequiredVersion, AllVersions, AllowPrerelease
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