function Search-PSFPowerShellGet {
	<#
	.SYNOPSIS
		Scan for available PowerShellGet versions.
	
	.DESCRIPTION
		Scan for available PowerShellGet versions.
		The module caches the availability of PowerShellGet features on import.
		It also automatically updates those settings when it knows to do so.

		However, if you change the configuration outside of the PSFramework.NuGet module,
		you may need to manually trigger the scan for the module to take the changes into account.

		For example, if you use Install-Module, rather than Install-PSFModule to install the
		latest version of PowerShellGet, use this command to make the module aware of the fact.
		Otherwise, this will automatically be run the next time the module is loaded.
	
	.PARAMETER UseCache
		Whether to respect the already available data and not do anything after all.
		Mostly for internal use.
	
	.EXAMPLE
		PS C:\> Search-PSFPowerShellGet
		
		Scan for available PowerShellGet versions.
	#>
	[CmdletBinding()]
	Param (
		[switch]
		$UseCache
	)
	
	process {
		if ($UseCache -and $script:psget.Count -gt 0) { return }

		$configuration = Get-PSFPowerShellGet
		$script:psget = @{
			'v2'           = $configuration.V2
			'v2CanInstall' = $configuration.V2CanInstall
			'v2CanPublish' = $configuration.V2CanPublish
			'v3'           = $configuration.V3
		}
	}
}
