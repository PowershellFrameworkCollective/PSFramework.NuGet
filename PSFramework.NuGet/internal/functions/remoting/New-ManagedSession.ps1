function New-ManagedSession {
	[CmdletBinding()]
	param (
		[PSFComputer[]]
		$ComputerName,

		[PSCredential]
		$Credential,

		[ValidateSet('Persistent', 'Temporary')]
		[string]
		$Type
	)
	begin {
		$param = @{ }
		if ($Credential) { $param.Credential = $Credential }
	}
	process {
		if (-not $ComputerName) { return }
		$sessionHash = @{ }
		@($ComputerName).Where{$_.Type -eq 'PSSession'}.ForEach{$sessionHash}
	}
}