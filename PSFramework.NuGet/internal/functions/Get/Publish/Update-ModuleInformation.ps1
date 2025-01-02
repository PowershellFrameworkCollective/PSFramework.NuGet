function Update-ModuleInformation {
	[CmdletBinding()]
	param (
		$Module,
		
		[string[]]
		$Tags,
		
		[string]
		$LicenseUri,
		
		[string]
		$IconUri,

		[string]
		$ProjectUri,

		[string]
		$ReleaseNotes,

		[string]
		$Prerelease,

		$Cmdlet = $PSCmdlet,

		[switch]
		$Continue
	)
	process {
		# If Nothing to do, do nothing
		if (-not ($Tags -or $LicenseUri -or $IconUri -or $ProjectUri -or $ReleaseNotes -or $Prerelease)) { return }

		$killIt = $ErrorActionPreference -eq 'Stop'

		$manifestPath = Join-Path -Path $Module.Path -ChildPath "$($Module.Name).psd1"

		$tokens = $null
		$errors = $null
		$ast = [System.Management.Automation.Language.Parser]::ParseFile($manifestPath, [ref]$tokens, [ref]$errors)

		$mainHash = $ast.FindAll({
				$args[0] -is [System.Management.Automation.Language.HashtableAst] -and
				$args[0].KeyValuePairs.Item1.Value -contains 'RootModule' -and
				$args[0].KeyValuePairs.Item1.Value -Contains 'ModuleVersion'
			}, $true)

		if (-not $mainHash) {
			Stop-PSFFunction -String 'Update-ModuleInformation.Error.BadManifest' -StringValues $module.Name, $manifestPath -Cmdlet $Cmdlet -EnableException $killIt -Continue:$Continue
			return
		}
		
		$privateData = [ordered]@{
			PSData = [ordered]@{ }
		}
		$replacements = @{ }
		
		$privateDataAst = $mainHash.KeyValuePairs | Where-Object { $_.Item1.Value -eq 'PrivateData' } | ForEach-Object { $_.Item2.PipelineElements[0].Expression }

		if ($privateDataAst) {
			foreach ($pair in $privateDataAst.KeyValuePairs) {
				if ($pair.Item1.Value -ne 'PSData') {
					$id = "%PSF_$(Get-Random)%"
					$privateData[$pair.Item1.Value] = $id
					$replacements[$id] = $pair.Item2.Extent.Text
					continue
				}

				foreach ($subPair in $pair.Item2.PipelineElements[0].Expression.KeyValuePairs) {
					$id = "%PSF_$(Get-Random)%"
					$privateData.PSData[$subPair.Item1.Value] = $id
					$replacements[$id] = $subPair.Item2.Extent.Text
				}
			}
		}

		if ($Tags) { $privateData.PSData['Tags'] = $Tags }
		if ($LicenseUri) { $privateData.PSData['LicenseUri'] = $LicenseUri }
		if ($IconUri) { $privateData.PSData['IconUri'] = $IconUri }
		if ($ProjectUri) { $privateData.PSData['ProjectUri'] = $ProjectUri }
		if ($ReleaseNotes) { $privateData.PSData['ReleaseNotes'] = $ReleaseNotes }
		if ($Prerelease) { $privateData.PSData['Prerelease'] = $Prerelease }

		$privateDataString = $privateData | ConvertTo-Psd1 -Depth 5
		foreach ($pair in $replacements.GetEnumerator()) {
			$privateDataString = $privateDataString -replace "'$($pair.Key)'", $pair.Value
		}

		if (-not $privateDataAst) {
			$newManifest = $ast.Extent.Text.Insert(($mainHash.Extent.EndOffset - 1), "PrivateData = $privateDataString")
		}
		else {
			$newManifest = $ast.Extent.Text.SubString(0, $privateDataAst.Extent.StartOffset) + $privateDataString + $ast.Extent.Text.SubString($privateDataAst.Extent.EndOffset)
		}
		$newManifest | Set-Content -Path $manifestPath
	}
}