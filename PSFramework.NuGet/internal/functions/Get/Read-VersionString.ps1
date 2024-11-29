function Read-VersionString {
	<#
	.SYNOPSIS
		Parses a Version String to work for PSGet V2 & V3
	
	.DESCRIPTION
		Parses a Version String to work for PSGet V2 & V3

		Supported Syntax:
		<Prefix><Version><Connector><Version><Suffix>

		Prefix: "[" (-ge) or "(" (-gt) or nothing (-ge)
		Version: A valid version of 2-4 elements or nothing
		Connector: A "," or a "-"
		Suffix: "]" (-le) or ")" (-lt) or nothing (-le)
	
	.PARAMETER Version
		The Version string to parse.
	
	.PARAMETER Cmdlet
		The $PSCmdlet variable of the caller.
		As this is an internal utility command, this allows it to terminate in the context of the calling command and remain invisible to the user.
	
	.EXAMPLE
		PS C:\> Read-VersionString -Version '[1.0.0,2.0.0)' -Cmdlet $PSCmdlet
		
		Resolves to a version object with a minimum version of 1.0.0 and less than 2.0.0.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Version,

		$Cmdlet = $PSCmdlet
	)
	process {
		$result = [PSCustomObject]@{
			V3String = ''
			Required = ''
			Minimum = ''
			Maximum = ''
			Prerelease = $false
		}

		# Plain Version
		if ($Version -as [version]) {
			$result.V3String = $Version
			$result.Required = $Version
			return $result
		}

		# Plain Version with Prerelease Tag
		if ($Version -match '^\d+(\.\d+){1,3}-\D') {
			$result.V3String = $Version -replace '-\D.*$'
			$result.Required = $Version -replace '-\D.*$'
			$result.Prerelease = $true
			return $result
		}

		<#
		Must match <Prefix><Version><Connector><Version><Suffix>
		Prefix: "[" (-ge) or "(" (-gt) or nothing (-ge)
		Version: A valid version of 2-4 elements or nothing
		Connector: A "," or a "-"
		Suffix: "]" (-le) or ")" (-lt) or nothing (-le)
		#>
		if ($Version -notmatch '^(\[|\(){0,1}(\d+(\.\d+){1,3}){0,1}(-|,)(\d+(\.\d+){1,3}){0,1}(\]|\)){0,1}$') {
			Stop-PSFFunction -String 'Read-VersionString.Error.BadFormat' -StringValues $Version -EnableException $true -Cmdlet $Cmdlet -Category InvalidArgument
		}

		$startGT = $Version -match '^\('
		$endGT = $Version -match '\)$'
		$lower, $higher = $Version -replace '\[|\]|\(|\)' -split ',|-'

		$v3Start = '['
		if ($startGT) { $v3Start = '(' }
		$v3End = ']'
		if ($endGT) { $v3End = ')' }
		$result.V3String = "$($v3Start)$($lower),$($higher)$($v3End)"
		if ($lower) {
			$result.Minimum = $lower -as [version]
			if ($startGT) {
				$parts = $lower -split '\.'
				$parts[-1] = 1 + $parts[-1]
				$result.Minimum = $parts -join '.'
			}
		}
		if ($higher) {
			if ($higher -match '^0(\.0){1,3}$') {
				Stop-PSFFunction -String 'Read-VersionString.Error.BadFormat.ZeroUpperBound' -StringValues $Version -EnableException $true -Cmdlet $Cmdlet -Category InvalidArgument
			}

			$result.Maximum = $higher -as [version]
			if ($endGT) {
				$parts = $higher -split '\.'
				$index = $parts.Count - 1
				do {
					if (0 -lt $parts[$index]) {
						$parts[$index] = -1 + $parts[$index]
						break
					}
					$index--
				}
				until ($index -lt 0)

				if ($index -lt ($parts.Count - 1)) {
					foreach ($position in ($index + 1)..($parts.Count - 1)) {
						$parts[$position] = 999
					}
				}

				$result.Maximum = $parts -join '.'
			}
		}

		$result
	}
}