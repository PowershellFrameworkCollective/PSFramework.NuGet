function Save-PSFPowerShellGet {
	[CmdletBinding()]
	param (
		[PsfValidateScript('PSFramework.Validate.FSPath.Folder', ErrorMessage = 'PSFramework.Validate.FSPath.Folder')]
		[string]
		$Path
	)

	if (-not $Path) {
		$rootPath = Join-Path -Path (Get-PSFPath -Name AppData) -ChildPath 'PowerShell/PSFramework/modules/PowerShellGet'
		if (-not (Test-Path -LiteralPath $rootPath)) {
			$null = New-Item -LiteralPath $rootPath -ItemType Directory -Force
		}
	}

	$links = @(
		'PSGetV2'
		'PSGetV3'
		'PSPkgMgmt'
	)

	$pkgData = @{ }

	foreach ($link in $links) {
		$resolvedUrl = Resolve-AkaMsLink -Name $link
		if (-not $resolvedUrl) {
			Stop-PSFFunction -String 'Save-PowerShellGet.Error.UnableToResolve' -StringValues $link -EnableException $true -Cmdlet $PSCmdlet
		}

		$pkgData[$link] = [PSCustomObject]@{
			Type = $link
			Name = ($resolvedUrl -split '/')[-2]
			Version = ($resolvedUrl -split '/')[-1]
			Resolved = $resolvedUrl
			FileName = ''
		}
		$pkgData[$link].FileName = '{0}-{1}.zip' -f $pkgData[$link].Name, $pkgData[$link].Version
	}

	$directory = New-PSFTempDirectory -Name psget -ModuleName PSFramework.NuGet
	foreach ($entry in $pkgData.Values) {
		Invoke-WebRequest -Uri $entry.Resolved -OutFile "$directory\temp-$($entry.Type).zip"
		$rootFolder = "$directory\$($entry.Type)"
		Expand-Archive -Path "$directory\temp-$($entry.Type).zip" -DestinationPath $rootFolder -Force

		# Cleanup nupkg residue
		$contentTypesPath = Join-Path -Path $rootFolder -ChildPath '[Content_Types].xml'
		Remove-Item -LiteralPath $contentTypesPath # LiteralPath so that the brackets don't interfere
		$relsPath = Join-Path -Path $rootFolder -ChildPath '_rels'
		Remove-Item -LiteralPath $relsPath -Force -Recurse
		$specPath = Join-Path -Path $rootFolder -ChildPath "$($entry.Name).nuspec"
		Remove-Item -LiteralPath $specPath -Force -Recurse
		$packagePath = Join-Path -Path $rootFolder -ChildPath 'package'
		Remove-Item -LiteralPath $packagePath -Force -Recurse

		# Cleanup Original download zip
		Remove-Item "$directory\temp-$($entry.Type).zip"

		# Create new zip file and delete old folder
		Compress-Archive -Path "$rootFolder\*" -DestinationPath "$directory\$($entry.FileName)"
		Remove-Item -LiteralPath $rootFolder -Recurse -Force
	}
	$pkgData | ConvertTo-Json | Set-Content -Path "$directory\modules.json"

	Copy-Item -Path $directory\* -Destination $Path -Force -Recurse
	Remove-PSFTempItem -Name psget -ModuleName PSFramework.NuGet
}