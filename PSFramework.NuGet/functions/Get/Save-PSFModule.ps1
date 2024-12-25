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
		$resolvedPaths = Resolve-RemotePath -Path $Path -ComputerName $ComputerName -TargetHandling Any -Cmdlet $PSCmdlet # Errors for bad paths, terminates if no path
		
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
			#TODO: Implement
			Publish-StagingModule -Path $tempDirectory -TargetPath $resolvedPaths -Force:$Force -Cmdlet $PSCmdlet
		}
		finally {
			Remove-PSFTempItem -Name Staging -ModuleName PSFramework.NuGet
		}
	}
}
