function Install-PSFModule {
	[CmdletBinding(PositionalBinding = $false, DefaultParameterSetName = 'ByName', SupportsShouldProcess = $true)]
	Param (
		[Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByName')]
		[string[]]
		$Name,

		[Parameter(ParameterSetName = 'ByName')]
		[string]
		$Version,

		[Parameter(ParameterSetName = 'ByName')]
		[switch]
		$Prerelease,

		[PsfValidateSet(TabCompletion = 'PSFramework.NuGet.ModuleScope')]
		[PsfArgumentCompleter('PSFramework.NuGet.ModuleScope')]
		[string]
		$Scope,

		[PSFComputer[]]
		$ComputerName,

		[switch]
		$SkipDependency,

		[switch]
		$AuthenticodeCheck = (Get-PSFConfigValue -FullName 'PSFramework.NuGet.Install.AuthenticodeSignature.Check'),

		[switch]
		$Force,

		[PSCredential]
		$Credential,

		[PSCredential]
		$RemotingCredential,

		[ValidateRange(1, [int]::MaxValue)]
		[int]
		$ThrottleLimit = (Get-PSFConfigValue -FullName 'PSFramework.NuGet.Remoting.Throttling'),

		[PsfArgumentCompleter('PSFramework.NuGet.Repository')]
		[string[]]
		$Repository = ((Get-PSFrepository).Name | Sort-Object -Unique),

		[switch]
		$TrustRepository,

		[ValidateSet('All', 'V2', 'V3')]
		[string]
		$Type = 'All',

		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'ByObject')]
		[object[]]
		$InputObject
	)
	
	begin {
		
	}
	process {
		#TODO: Implement
	}
	end {
	
	}
}
