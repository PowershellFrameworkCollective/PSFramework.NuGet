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
		throw "Not implemented yet!"

		$killIt = $ErrorActionPreference -eq 'Stop'
		$cleanedUp = $false

		# Resolution only happens to early detect impossible parameterization. Will be called again in Save-PSFModule.
		$null = Resolve-Repository -Name $Repository -Type $Type -Cmdlet $PSCmdlet # Terminates if no repositories found
		$managedSessions = New-ManagedSession -ComputerName $ComputerName -Credential $RemotingCredential -Cmdlet $PSCmdlet -Type Temporary
		if ($ComputerName -and -not $managedSessions) {
			Stop-PSFFunction -String 'Install-PSFModule.Error.NoComputerValid' -EnableException $killIt -Cmdlet $PSCmdlet
			return
		}
		$resolvedPaths = Resolve-ModuleScopePath -Scope $Scope -ManagedSession $managedSessions -TargetHandling Any -Cmdlet $PSCmdlet # Errors for bad paths, terminates if no path

		# Used to declare variable in the current scope, to prevent variable lookup snafus when det
		$command = $null
		$saveParam = $PSBoundParameters | ConvertTo-PSFHashtable -ReferenceCommand Save-PSFModule -Exclude ComputerName, RemotingCredential
		$saveParam.Path = '<placeholder>' # Meet Parameterset requirements
	}
	process {
		if (Test-PSFFunctionInterrupt) { return }

		#region Start Nested Save-PSFModule
		if (-not $command) {
			$command = { Save-PSFModule @saveParam -PathInternal $resolvedPaths -Cmdlet $PSCmdlet -ErrorAction $ErrorActionPreference }.GetSteppablePipeline()
			try { $command.Begin((-not $Name)) }
			catch {
				if (-not $cleanedUp -and $managedSessions) { $managedSessions | Where-Object Type -EQ 'Temporary' | ForEach-Object Session | Remove-PSSession }
				$cleanedUp = $true
				Stop-PSFFunction -String 'Install-PSFModule.Error.Setup' -ErrorRecord $_ -EnableException $killIt -Cmdlet $PSCmdlet
				return
			}
		}
		#endregion Start Nested Save-PSFModule

		#region Execute Process
		try {
			if ($Name) { $command.Process() }
			else { $command.Process($InputObject) }
		}
		catch {
			if (-not $cleanedUp -and $managedSessions) { $managedSessions | Where-Object Type -EQ 'Temporary' | ForEach-Object Session | Remove-PSSession }
			$cleanedUp = $true
			Stop-PSFFunction -String 'Install-PSFModule.Error.Installation' -ErrorRecord $_ -EnableException $killIt -Cmdlet $PSCmdlet
			return
		}
		#endregion Execute Process
	}
	end {
		if (-not $cleanedUp -and $managedSessions) { $managedSessions | Where-Object Type -EQ 'Temporary' | ForEach-Object Session | Remove-PSSession }
		if (Test-PSFFunctionInterrupt) { return }
		$null = $command.End()
	}
}
