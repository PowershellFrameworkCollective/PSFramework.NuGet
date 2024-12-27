function Resolve-AkaMsLink {
	<#
	.SYNOPSIS
		Resolves an aka.ms shortcut link to its full address.
	
	.DESCRIPTION
		Resolves an aka.ms shortcut link to its full address.
		This is done by sending the web request against it while limiting the redirect count to 1, then reading the error.
	
	.PARAMETER Name
		The full link or shorthand to resolve.
		Can take any of the following notations:
		+ https://aka.ms/psgetv3
		+ aka.ms/psgetv3
		+ psgetv3
	
	.EXAMPLE
		PS C:\> Resolve-AkaMsLink -Name psgetv3
		
		Returns the Url https://aka.ms/psgetv3 points to.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[string]
		$Name
	)

	process {
		if ($Name -notmatch 'aka\.ms') {
			$Name = 'https://aka.ms/{0}' -f $Name.TrimStart("/")
		}
		if ($Name -notmatch '^https://') {
			$Name = 'https://{0}' -f $Name.TrimStart("/")
		}
	
		try { $null = Invoke-WebRequest -Uri $Name -MaximumRedirection 1 -ErrorAction Stop }
		catch {
			# Not doing a version check, since exact cut-over version between behaviors unknown
			# PS ?+
			if ($_.TargetObject.RequestUri.AbsoluteUri) {
				$_.TargetObject.RequestUri.AbsoluteUri
			}
			# PS 5.1
			else {
				$_.TargetObject.Address.AbsoluteUri
			}
		}
	}
}