function Save-PSFModule {
	<#
	.SYNOPSIS
		Downloads modules to a specified path.
	
	.DESCRIPTION
		Downloads modules to a specified path.
		Supports flexible repository resolution, modern versioning and deployment to remote systems.

		When specifying remote computers, all file transfer is performed via PSRemoting only.

		ErrorAction is only honored for local deployments.
	
	.PARAMETER Name
		Name of the module to download.
	
	.PARAMETER Version
		Version constrains for the module to save.
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
	
	.PARAMETER Path
		Where to store the modules.
		If used together with the -ComputerName parameter, this is considered a local path from within the context of a remoting session to that computer,
		If you want to deploy a module to "\\server1\C$\Scripts\Modules" provide "C:\Scripts\Modules" as -Path, with "-ComputerName server1".
		Unless you actually WANT to deploy without remoting but with SMB (in which case do not provide a -ComputerName)
		See examples for less confusion :)
	
	.PARAMETER ComputerName
		The computers to deploy the modules to.
		Accepts both names or established PSRemoting sessions.
		The -Path parameter will be considered as a local path from within a remoting session.
		If you want to deploy a module to "\\ComputerName\C$\Scripts\Modules" provide "C:\Scripts\Modules" as -Path.
		See examples for less confusion :)

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

	.PARAMETER PathInternal
		For internal use only.
		Used to pass scope-based path resolution from Install-PSFModule into Save-PSFModule.

	.PARAMETER WhatIf
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
	
	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.
	
	.EXAMPLE
		PS C:\> Save-PSFModule EntraAuth -Path C:\temp
		
		Downloads the module "EntraAuth" to the local C:\temp path.

	.EXAMPLE
		PS C:\> Save-PSFModule -Name EntraAuth -Path 'C:\Program Files\WindowsPowerShell\Modules'

		Downloads the latest version of EntraAuth and places it where both PowerShell versions look for modules.

	.EXAMPLE
		PS C:\> Save-PSFModule -Name EntraAuth -Path 'C:\Program Files\WindowsPowerShell\Modules' -Force

		Downloads the latest version of EntraAuth and places it where both PowerShell versions look for modules.
		If the module has already been installed previously in the same version, it will replace the old install with the newly downloaded one.

	.EXAMPLE
		PS C:\> Save-PSFModule -Name EntraAuth -Path '\\server1\C$\Program Files\WindowsPowerShell\Modules'

		Downloads the latest version of EntraAuth and places it where both PowerShell versions look for modules ... on computer "server1".
		File transfer happens via SMB - lets hope that works.

	.EXAMPLE
		PS C:\> Save-PSFModule -Name EntraAuth -Path 'C:\Program Files\WindowsPowerShell\Modules' -ComputerName server1

		Downloads the latest version of EntraAuth and places it where both PowerShell versions look for modules ... on computer "server1".
		File transfer happens via PSRemoting, assuming our account has local admin rights on the remote computer.

	.EXAMPLE
		PS C:\> Save-PSFModule -Name EntraAuth -Path 'C:\Program Files\WindowsPowerShell\Modules' -ComputerName server1 -RemotingCredential $cred

		Downloads the latest version of EntraAuth and places it where both PowerShell versions look for modules ... on computer "server1".
		File transfer happens via PSRemoting, assuming the account in $cred has local admin rights on the remote computer.

	.EXAMPLE
		PS C:\> Save-PSFModule -Name EntraAuth -Path '/usr/local/share/powershell/Modules' -ComputerName $sessions

		Downloads the latest version of EntraAuth and places it where both PowerShell versions look for modules on linux distributions ... on the computers previously connected.
		On PowerShell 7, these can be remoting sessions established via SSH.
		File transfer happens via PSRemoting.
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
		$InputObject,

		[Parameter(DontShow = $true)]
		$PathInternal
	)
	
	begin {
		$repositories = Resolve-Repository -Name $Repository -Type $Type -Cmdlet $PSCmdlet # Terminates if no repositories found
		if ($PathInternal) {
			$resolvedPaths = $PathInternal
		}
		else {
			$managedSessions = New-ManagedSession -ComputerName $ComputerName -Credential $RemotingCredential -Cmdlet $PSCmdlet -Type Temporary
			if ($ComputerName -and -not $managedSessions) {
				Stop-PSFFunction -String 'Save-PSFModule.Error.NoComputerValid' -EnableException ($ErrorActionPreference -eq 'Stop') -Cmdlet $PSCmdlet
				return
			}
			$resolvedPaths = Resolve-RemotePath -Path $Path -ComputerName $managedSessions.Session -ManagedSession $managedSessions -TargetHandling Any -Cmdlet $PSCmdlet # Errors for bad paths, terminates if no path
		}
		
		$tempDirectory = New-PSFTempDirectory -Name Staging -ModuleName PSFramework.NuGet
	}
	process {
		if (Test-PSFFunctionInterrupt) { return }

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
			# Cleanup Managed sessions only if created locally. With -PathInternal, managed sessions are managed by the caller.
			if (-not $PathInternal) {
				$managedSessions | Where-Object Type -EQ 'Temporary' | ForEach-Object Session | Remove-PSSession
			}
			Remove-PSFTempItem -Name Staging -ModuleName PSFramework.NuGet
		}
	}
}