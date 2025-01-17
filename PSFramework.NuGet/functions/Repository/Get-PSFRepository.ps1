function Get-PSFRepository {
	<#
	.SYNOPSIS
		Lists available PowerShell repositories.
	
	.DESCRIPTION
		Lists available PowerShell repositories.
		Includes both classic (V2 | Get-PSRepository) and new (V3 | Get-PSResourceRepository) repositories.
		This will also include additional metadata, including priority, which in this module is also applicable to classic repositories.

		Note on Status:
		In V2 repositories, the status can show "NoPublish" or "NoInstall".
		This is determined by whether it has been bootstrapped at the system level.
		If you have already bootstrapped it in user-mode, this may not be reflected correctly.
		If your computer is internet-facing, it can also automatically bootstrap itself without any issues.
	
	.PARAMETER Name
		Name of the repository to list.
	
	.PARAMETER Type
		What kind of repository to return:
		+ All: (default) Return all, irrespective of type
		+ V2: Only return classic repositories, as would be returned by Get-PSRepository
		+ V3: Only return modern repositories, as would be returned by Get-PSResourceRepository
	
	.EXAMPLE
		PS C:\> Get-PSFRepository

		List all available repositories.
	#>
	[CmdletBinding()]
	Param (
		[PsfArgumentCompleter('PSFramework.NuGet.Repository')]
		[string[]]
		$Name = '*',

		[ValidateSet('All','V2','V3')]
		[string]
		$Type = 'All'
	)
	
	begin {
		Search-PSFPowerShellGet -UseCache
	}
	process {
		if ($script:psget.V3 -and $Type -in 'All','V3') {
			foreach ($repository in Get-PSResourceRepository -Name $Name -ErrorAction Ignore) {
				if (-not $repository) [ continue ]
				[PSCustomObject]@{
					PSTypeName = 'PSFramework.NuGet.Repository'
					Name       = $repository.Name
					Type       = 'V3'
					Status     = 'OK'
					Trusted    = $repository.Trusted
					Priority   = Get-PSFConfigValue -FullName "PSFramework.NuGet.Repositories.$($repository.Name).Priority" -Fallback $repository.Priority
					Uri        = $repository.Uri
					Object     = $repository
					Credential = Get-PSFConfigValue -FullName "PSFramework.NuGet.Repositories.$($repository.Name).Credential"
				}
			}
		}
		if ($script:psget.V2 -and $Type -in 'All','V2') {
			$status = 'OK'
			if (-not $script:psget.v2CanPublish) { $status = 'NoPublish' }
			if (-not $script:psget.v2CanInstall) { $status = 'NoInstall' }

			foreach ($repository in Get-PSRepository -Name $Name -ErrorAction Ignore) {
				if (-not $repository) [ continue ]
				[PSCustomObject]@{
					PSTypeName = 'PSFramework.NuGet.Repository'
					Name       = $repository.Name
					Type       = 'V2'
					Status     = $status
					Trusted    = $repository.Trusted
					Priority   = Get-PSFConfigValue -FullName "PSFramework.NuGet.Repositories.$($repository.Name).Priority" -Fallback 100
					Uri        = $repository.SourceLocation
					Object     = $repository
					Credential = Get-PSFConfigValue -FullName "PSFramework.NuGet.Repositories.$($repository.Name).Credential"
				}
			}
		}
	}
}