function ConvertTo-TransportFile {
	<#
	.SYNOPSIS
		Wraps up the payload of a resoure module into a single archive.
	
	.DESCRIPTION
		Wraps up the payload of a resoure module into a single archive.
		This is unfortunately required to maintain content fidelity, due to errors in the PSResourceGet module.
		Before creating the archive, we place a dummy file in every empty folder, to prevent it from being skipped.
	
	.PARAMETER Path
		Path to the Resource folder, containing the files & folders to wrap up.
	
	.EXAMPLE
		PS C:\> ConvertTo-TransportFile -Path $resourcePath
	
		Wraps up the specified payload into a single archive.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Path
	)
	process {
		$directories = Get-ChildItem -LiteralPath $Path -Recurse -Directory
		foreach ($directory in $directories) {
			$countChildren = $directory.GetFileSystemInfos('*', [System.IO.SearchOption]::TopDirectoryOnly).Count
			if ($countChildren -gt 0) { continue }

			$null = New-Item -Path $directory.FullName -Name '___þþþ_transportplaceholder_þþþ___.txt' -ItemType File -Value 42
		}

		$archivePath = Join-Path -Path $Path -ChildPath '___þþþ_transportplaceholder_þþþ___.zip'
		$items = Get-ChildItem -LiteralPath $Path
		Compress-Archive -LiteralPath $items.FullName -DestinationPath $archivePath -Force
		$items | Remove-Item -Recurse -Force
	}
}