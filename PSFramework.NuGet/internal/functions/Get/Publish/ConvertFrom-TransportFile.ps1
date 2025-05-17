function ConvertFrom-TransportFile {
	<#
	.SYNOPSIS
		Unwraps a previously created transport file.
	
	.DESCRIPTION
		Unwraps a previously created transport file.
		These are created as part of the publishing step of resource modules, in order to ensure transport fidelity with PSResourceGet.
		This command will expand the transport archive and remove the placeholder files previously created.
	
	.PARAMETER Path
		The path to the Resources folder within the Resource Module being downloaded.
	
	.EXAMPLE
		PS C:\> ConvertFrom-TransportFile -Path $dataPath
		
		Unwraps any transport file in the specified resources directory.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Path
	)
	process {
		$archivePath = Join-Path -Path $Path -ChildPath '___þþþ_transportplaceholder_þþþ___.zip'
		if (-not (Test-Path -LiteralPath $archivePath)) { return }

		Expand-Archive -Path $archivePath -DestinationPath $Path
		Remove-Item -LiteralPath $archivePath -Force

		Get-ChildItem -LiteralPath $Path -Recurse -Force | Where-Object Name -eq '___þþþ_transportplaceholder_þþþ___.txt' | Remove-Item
	}
}