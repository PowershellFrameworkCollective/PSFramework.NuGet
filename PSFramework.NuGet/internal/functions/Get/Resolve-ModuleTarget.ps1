function Resolve-ModuleTarget {
	<#
	.SYNOPSIS
		Resolves the search criteria for modules to save or install.
	
	.DESCRIPTION
		Resolves the search criteria for modules to save or install.
		For each specified module, it will return a result including the parameters Save-Module and Save-PSResource will need.
	
	.PARAMETER InputObject
		A module object to retrieve. Can be the output of Get-Module, Find-Module, Find-PSResource or Find-PSFModule.
	
	.PARAMETER Name
		The name of the module to resolve.
	
	.PARAMETER Version
		The version condition for the module. Supports a fairly flexible syntax.
		Examples:
		- 2.0.0 # Exactly v2.0.0
		- 2.1.0-RC2 # Preview "RC2" of exactly version 2.1.0
		- 2.0.0-2.4.5 # Any version at least 2.0.0 and at most 2.4.5
		- [2.0,3.0) # At least 2.0 but less than 3.0
		- [2.0-3.0) # At least 2.0 but less than 3.0
	
	.PARAMETER Prerelease
		Include Prerelease versions.
		Redundant if asking for a specific version with a specific prerelease suffix.
	
	.PARAMETER Cmdlet
		The $PSCmdlet variable of the caller.
		As this is an internal utility command, this allows it to terminate in the context of the calling command and remain invisible to the user.
	
	.EXAMPLE
		PS C:\> Resolve-ModuleTarget -InputObject $InputObject -Cmdlet $PSCmdlet

		Resolves the object as a module target.
		In case of error, the terminating error will happen within the scope of the caller.
	#>
	[CmdletBinding()]
	param (
		[Parameter(ValueFromPipeline = $true, ParameterSetName = 'ByObject')]
		[object[]]
		$InputObject,

		[Parameter(ParameterSetName = 'ByName')]
		[string[]]
		$Name,

		[Parameter(ParameterSetName = 'ByName')]
		[AllowEmptyString()]
		[string]
		$Version,

		[Parameter(ParameterSetName = 'ByName')]
		[switch]
		$Prerelease,

		$Cmdlet = $PSCmdlet
	)
	begin {
		function New-ModuleTarget {
			[CmdletBinding()]
			param (
				$Object,

				[string]
				$Name,

				[AllowEmptyString()]
				[string]
				$Version,

				[switch]
				$Prerelease,

				$Cmdlet
			)

			$v2Param = @{ }
			$v3Param = @{ }
			$actualName = $Name
			$versionString = ''

			if ($Object) {
				$v3Param.InputObject = $Object
				$v2Param.Name = $Object.Name
				$v2Param.RequiredVersion = $Object.AdditionalMetadata.NormalizedVersion
				$versionString = $Object.AdditionalMetadata.NormalizedVersion
				$actualName = $Object.Name

				# V3
				if ($Object.IsPrerelease) { $v2Param.AllowPrerelease = $true }
				# V2
				if ($Object.AdditionalMetadata.IsPrerelease) { $v2Param.AllowPrerelease = $true }

				# Get-Module
				if ($Object -is [System.Management.Automation.PSModuleInfo]) {
					$versionString = $Object.Version
					$v2Param.RequiredVersion = $Object.Version
					if ($Object.PrivateData.PSData.Prerelease) {
						$v2Param.AllowPrerelease = $true
						$v2Param.RequiredVersion = '{0}-{1}' -f $Object.Version, $Object.PrivateData.PSData.Prerelease
					}
				}
			}
			else {
				$v2Param.Name = $Name
				$v3Param.Name = $Name
				if ($Prerelease) {
					$v2Param.AllowPrerelease = $true
					$v3Param.Prerelease = $true
				}
				if ($Version) {
					$versionData = Read-VersionString -Version $Version -Cmdlet $Cmdlet
					$v3Param.Version = $versionData.V3String
					if ($versionData.Required) { $v2Param.RequiredVersion = $versionData.Required }
					else {
						if ($versionData.Minimum) { $v2Param.MinimumVersion = $versionData.Minimum }
						if ($versionData.Maximum) { $v2Param.MaximumVersion = $versionData.Maximum }
					}
					if ($versionData.Prerelease) {
						$v2Param.AllowPrerelease = $true
						$v3Param.Prerelease = $true
					}
				}
			}

			[PSCustomObject]@{
				PSTypeName = 'PSFramework.NuGet.ModuleTarget'
				Name       = $actualName
				Version    = $versionString
				V2Param    = $v2Param
				V3Param    = $v3Param
			}
		}
	}
	process {
		foreach ($object in $InputObject) {
			# Case 1: Find-PSFModule
			if ($object.PSObject.TypeNames -contains 'PSFramework.NuGet.ModuleInfo') {
				New-ModuleTarget -Object $object.Object -Cmdlet $Cmdlet
			}
			# Case 2: Find-Module
			# Case 3: Find-PSResource
			# Case 4: Get-Module
			else {
				New-ModuleTarget -Object $object -Cmdlet $Cmdlet
			}
		}
		foreach ($nameEntry in $Name) {
			New-ModuleTarget -Name $nameEntry -Version $Version -Prerelease:$Prerelease -Cmdlet $Cmdlet
		}
	}
}