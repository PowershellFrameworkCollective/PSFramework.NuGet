function Install-PSFModule {
	<#
	.SYNOPSIS
		Installs PowerShell modules from a PowerShell repository.
	
	.DESCRIPTION
		Installs PowerShell modules from a PowerShell repository.
		They can be installed locally or to remote computers.
	
	.PARAMETER Name
		Name of the module to install.
	
	.PARAMETER Version
		Version constrains for the module to install.
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
	
	.PARAMETER Prerelease
		Whether to include prerelease versions in the potential results.
	
	.PARAMETER Scope
		Where to install the module to.
		Use Register-PSFModuleScope to add additional scopes to the list of options.
		Scopes can either use a static path or dynamic code to calculate - per computer - where to install the module.
		If not specified, it will default to:
		- CurrentUser - for local installation (irrespective of whether the console is run "As Administrator" or not.)
		- AllUsers - for remote installations when using the -ComputerName parameter.
	
	.PARAMETER ComputerName
		The computers to deploy the modules to.
		Accepts both names or established PSRemoting sessions.
		All transfer happens via PowerShell Remoting.

		If you provide names, by default this module will connect to the "Microsoft.PowerShell" configuration name.
		To change that name, use the 'PSFramework.NuGet.Remoting.DefaultConfiguration' configuration setting.
	
	.PARAMETER SkipDependency
		Do not include any dependencies.
		Works with PowerShellGet V1/V2 as well.
	
	.PARAMETER AuthenticodeCheck
		Whether modules must be correctly signed by a trusted source.
		Uses "Get-PSFModuleSignature" for validation.
		Defaults to: $false
		Default can be configured under the 'PSFramework.NuGet.Install.AuthenticodeSignature.Check' setting.
	
	.PARAMETER Force
		Redeploy a module that already exists in the target path.
		By default it will skip modules that do already exist in the target path.
	
	.PARAMETER Credential
		The credentials to use for connecting to the Repository (NOT the remote computers).

	.PARAMETER RemotingCredential
		The credentials to use for connecting to remote computers we want to deploy modules to via remoting.
		These will NOT be used for repository access.
	
	.PARAMETER ThrottleLimit
		Up to how many computers to deploy the modules to in parallel.
		Defaults to: 5
		Default can be configured under the 'PSFramework.NuGet.Remoting.Throttling' setting.
	
	.PARAMETER Repository
		Repositories to install from. Respects the priority order of repositories.
		See Get-PSFRepository for available repositories (and their priority).
		Lower numbers are installed from first.
	
	.PARAMETER TrustRepository
		Whether we should trust the repository installed from and NOT ask users for confirmation.
	
	.PARAMETER Type
		What type of repository to download from.
		V2 uses classic Save-Module.
		V3 uses Save-PSResource.
		Availability depends on the installed PSGet module versions and configured repositories.
		Use Install-PSFPowerShellGet to deploy the latest versions of the package modules.

		Only the version on the local computer matters, even when deploying to remote computers.
	
	.PARAMETER InputObject
		The module to install.
		Takes the output of Get-Module, Find-Module, Find-PSResource and Find-PSFModule, to specify the exact version and name of the module.
		Even when providing a locally available version, the module will still be downloaded from the repositories chosen.

	.PARAMETER WhatIf
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
	
	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.
	
	.EXAMPLE
		PS C:\> Install-PSFModule -Name EntraAuth

		Installs the EntraAuth module locally for the CurrentUser.

	.EXAMPLE
		PS C:\> Install-PSFModule -Name ADMF -ComputerName AdminHost1, AdminHost2

		Installs the ADMF module (and all of its dependencies) for All Users on the computers AdminHost1 and AdminHost2

	.EXAMPLE
		PS C:\> Install-PSFModule -Name string, PoshRSJob -ComputerName $sshSessions -Scope ScriptModules

		Installs the String and PoshRSJob module to all computers with an established session in $sshSessions.
		The modules will be installed to the "ScriptModules" scope - something that must have first been registered
		using the Register-PSFModuleScope command.
	#>
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
		$killIt = $ErrorActionPreference -eq 'Stop'
		$cleanedUp = $false

		# Resolution only happens to early detect impossible parameterization. Will be called again in Save-PSFModule.
		$null = Resolve-Repository -Name $Repository -Type $Type -Cmdlet $PSCmdlet # Terminates if no repositories found
		$managedSessions = New-ManagedSession -ComputerName $ComputerName -Credential $RemotingCredential -Cmdlet $PSCmdlet -Type Temporary
		if ($ComputerName -and -not $managedSessions) {
			Stop-PSFFunction -String 'Install-PSFModule.Error.NoComputerValid' -StringValues ($ComputerName -join ', ') -EnableException $killIt -Cmdlet $PSCmdlet
			return
		}
		$resolvedPaths = Resolve-ModuleScopePath -Scope $Scope -ManagedSession $managedSessions -TargetHandling Any -PathHandling Any -Cmdlet $PSCmdlet # Errors for bad paths, terminates if no path

		# Used to declare variable in the current scope, to prevent variable lookup snafus when det
		$command = $null
		$saveParam = $PSBoundParameters | ConvertTo-PSFHashtable -ReferenceCommand Save-PSFModule -Exclude ComputerName, RemotingCredential
		$saveParam.Path = '<placeholder>' # Meet Parameterset requirements
	}
	process {
		if (Test-PSFFunctionInterrupt) { return }

		$stopParam = @{ StringValues = $Name -join ', '}
		if ($InputObject) {
			$names = foreach ($item in $InputObject) {
				if ($item -is [string]) { $item }
				elseif ($item.ModuleName) { $item.ModuleName }
			}
			$stopParam = @{ StringValues = $names -join ', '}
		}
		
		#region Start Nested Save-PSFModule
		if (-not $command) {
			$command = { Save-PSFModule @saveParam -PathInternal $resolvedPaths -Cmdlet $PSCmdlet -ErrorAction $ErrorActionPreference }.GetSteppablePipeline()
			try { $command.Begin((-not $Name)) }
			catch {
				if (-not $cleanedUp -and $managedSessions) { $managedSessions | Where-Object Type -EQ 'Temporary' | ForEach-Object Session | Remove-PSSession }
				$cleanedUp = $true
				Stop-PSFFunction -String 'Install-PSFModule.Error.Setup' @stopParam -ErrorRecord $_ -EnableException $killIt -Cmdlet $PSCmdlet
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
			Stop-PSFFunction -String 'Install-PSFModule.Error.Installation' @stopParam -ErrorRecord $_ -EnableException $killIt -Cmdlet $PSCmdlet
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