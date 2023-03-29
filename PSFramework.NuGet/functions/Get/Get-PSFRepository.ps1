function Get-PSFRepository {
	[CmdletBinding()]
	Param (
		[string[]]
		$Name = '*'
	)
	
	begin {
		Search-PSFPowerShellGet -UseCache
	}
	process {
		if ($script:psget.V3) {
			foreach ($repository in Get-PSResourceRepository -Name $Name) {
				[PSCustomObject]@{
					PSTypeName = 'PSFramework.NuGet.Repository'
					Name       = $repository.Name
					Type       = 'V3'
					Status     = 'OK'
					Trusted    = $repository.Trusted
					Priority   = $repository.Priority
					Uri        = $repository.Uri
					Object     = $repository
				}
			}
		}
		if ($script:psget.V2) {
			$status = 'OK'
			if (-not $script:psget.v2CanPublish) { $status = 'NoPublish' }
			if (-not $script:psget.v2CanInstall) { $status = 'NoInstall' }

			foreach ($repository in Get-PSRepository -Name $Name) {
				[PSCustomObject]@{
					PSTypeName = 'PSFramework.NuGet.Repository'
					Name       = $repository.Name
					Type       = 'V2'
					Status     = $status
					Trusted    = $repository.Trusted
					Priority   = -1
					Uri        = $repository.SourceLocation
					Object     = $repository
				}
			}
		}
	}
}