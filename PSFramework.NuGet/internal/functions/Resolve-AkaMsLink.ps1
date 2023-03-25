function Resolve-AkaMsLink {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Name
	)

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