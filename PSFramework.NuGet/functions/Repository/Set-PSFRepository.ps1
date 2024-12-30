function Set-PSFRepository {
	<#
	.SYNOPSIS
		Configure existing powershell repositories or define a new one.
	
	.DESCRIPTION
		Configure existing powershell repositories or define a new one.
		This allows you to modify their metadata, notably registering credentials to use on all requests or modifying its priority.
		For defining new repositories, it is required to at least define "Type" and "Uri"
		
		Some updates - the Uri and Trusted state - require updating the configuration on the PSGet repository settings, rather than just being contained within this module.
		The command will handle that, which will be slightly slower and also affect direct use of the PSGet commands (such as install-Module or Install-PSResource).

		Settings will apply to all repositories with the same name.
		If you have the same repository configured in both V2 and V3, they BOTH will receive the update.
	
	.PARAMETER Name
		Name of the repository to modify.
		Wildcards not supported (unless you actually name a repository with a wildcard in the name. In which case you probably want reconsider your naming strategy.)
	
	.PARAMETER Priority
		The priority the repository should have.
		Lower-numbered repositories will beu sed before repositories with higher numbers.
	
	.PARAMETER Credential
		Credentials to use on all requests against the repository.

	.PARAMETER Uri
		The Uri from which modules are installed (and to which they are published).
		Will update the PSGet repositories objects.

	.PARAMETER Trusted
		Whether the repository is considered trusted.

	.PARAMETER Type
		What version of PSGet it should use.
		- Any: Will register as V3 if available, otherwise V2. Will not update to V3 if already on V2.
		- Update: Will register under highest version available, upgrading from older versions if already available on old versions
		- All: Will register on ALL available versions
		- V2: Will only register on V2. V3 - if present and configured - will be unregistered.
		- V2Preferred: Will only register on V2. If V2 does not exist, existing V3 repositories will be allowed.
		- V3: Will only register on V3. If V2 is present, it will be unregistered, irrespective of whether V3 is available.
	
	.PARAMETER Persist
		Whether the settings should be remembered.
		If settings are not persisted, they only last until the console is closed.
		When persisting credentials, they are - at least on windows - stored encrypted in registry (HKCU) and are only readable by the same user on the same computer.
	
	.EXAMPLE
		PS C:\> Set-PSFRepository -Name AzDevOps -Credential $cred

		Assigns for the repository "AzDevOps" the credentials stored in $cred.
		All subsequent PSGet calls through this module will be made using those credentials.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding(PositionalBinding = $false)]
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[PsfArgumentCompleter('PSFramework.NuGet.Repository')]
		[string]
		$Name,

		[int]
		$Priority,

		[PSCredential]
		$Credential,

		[string]
		$Uri,

		[bool]
		$Trusted,

		[ValidateSet('Any', 'Update', 'All', 'V2', 'V2Preferred', 'V3')]
		[string]
		$Type,

		[switch]
		$Persist
	)
	process {
		# Not all changes require a repository update run
		$mustUpdate = $false

		if ($PSBoundParameters.Keys -contains 'Priority') {
			Set-PSFConfig -FullName "PSFramework.NuGet.Repositories.$($Name).Priority" -Value $Priority
			if ($Persist) { Register-PSFConfig -FullName "PSFramework.NuGet.Repositories.$($Name).Priority" }
		}
		if ($PSBoundParameters.Keys -contains 'Credential') {
			Set-PSFConfig -FullName "PSFramework.NuGet.Repositories.$($Name).Credential" -Value $Credential
			if ($Persist) { Register-PSFConfig -FullName "PSFramework.NuGet.Repositories.$($Name).Credential" }
		}

		if ($Uri) {
			Set-PSFConfig -FullName "PSFramework.NuGet.Repositories.$($Name).Uri" -Value $Uri
			$mustUpdate = $true
			if ($Persist) { Register-PSFConfig -FullName "PSFramework.NuGet.Repositories.$($Name).Uri" }
		}
		if ($PSBoundParameters.Keys -contains 'Trusted') {
			Set-PSFConfig -FullName "PSFramework.NuGet.Repositories.$($Name).Trusted" -Value $Trusted
			$mustUpdate = $true
			if ($Persist) { Register-PSFConfig -FullName "PSFramework.NuGet.Repositories.$($Name).Trusted" }
		}
		if ($Type) {
			Set-PSFConfig -FullName "PSFramework.NuGet.Repositories.$($Name).Type" -Value $Type
			$mustUpdate = $true
			if ($Persist) { Register-PSFConfig -FullName "PSFramework.NuGet.Repositories.$($Name).Type" }
		}

		if ($mustUpdate) {
			Update-PSFRepository
		}
	}
}