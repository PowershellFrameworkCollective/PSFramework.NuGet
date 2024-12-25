function Save-PSFModule {
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

		[Parameter(Mandatory = $true, Position = 1)]
		[string]
		$Path,

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

		[ValidateRange(1,[int]::MaxValue)]
		[int]
		$ThrottleLimit = 5,

		[PsfArgumentCompleter('PSFramework.NuGet.Repository')]
		[string[]]
		$Repository,

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
		$repositories = Resolve-Repository -Name $Repository -Type $Type -Cmdlet $PSCmdlet # Terminates if no repositories found
		$managedSessions = New-ManagedSession -ComputerName $ComputerName -Cmdlet $PSCmdlet -Type Temporary
		$resolvedPaths = Resolve-RemotePath -Path $Path -ComputerName $managedSessions.Session -ManagedSession $managedSessions -TargetHandling Any -Cmdlet $PSCmdlet # Errors for bad paths, terminates if no path
		
		$tempDirectory = New-PSFTempDirectory -Name Staging -ModuleName PSFramework.NuGet
	}
	process {
		try {
			$installData = switch ($PSCmdlet.ParameterSetName) {
				ByObject { Resolve-ModuleTarget -InputObject $InputObject -Cmdlet $PSCmdlet }
				ByName { Resolve-ModuleTarget -Name $Name -Version $Version -Prerelease:$Prerelease -Cmdlet $PSCmdlet }
			}
			if (-not $PSCmdlet.ShouldProcess(($installData.TargetName -join ', '), "Saving modules to $Path")) {
				return
			}
			
			Save-StagingModule -InstallData $installData -Path $tempDirectory -Repositories $repositories -Cmdlet $PSCmdlet -Credential $Credential -SkipDependency:$SkipDependency -AuthenticodeCheck:$AuthenticodeCheck
			Publish-StagingModule -Path $tempDirectory -TargetPath $resolvedPaths -Force:$Force -Cmdlet $PSCmdlet -ThrottleLimit $ThrottleLimit
		}
		finally {
			Remove-PSFTempItem -Name Staging -ModuleName PSFramework.NuGet
		}
	}
}