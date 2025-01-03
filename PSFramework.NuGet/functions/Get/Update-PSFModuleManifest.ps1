function Update-PSFModuleManifest {
	[CmdletBinding()]
	param (
		$Path,
		
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

		[switch]
		$PassThru,

		$Cmdlet = $PSCmdlet,

		[switch]
		$Continue
	)
	begin {
		#region Utility Functions
		function Update-ManifestProperty {
			[OutputType([System.Management.Automation.Language.Ast])]
			[CmdletBinding()]
			param (
				[Parameter(Mandatory = $true)]
				[System.Management.Automation.Language.Ast]
				$Ast,

				[Parameter(Mandatory = $true)]
				[string]
				$Property,

				[Parameter(Mandatory = $true)]
				$Value,

				[Parameter(Mandatory = $true)]
				[ValidateSet('String', 'StringArray', 'HashtableArray')]
				[string]
				$Type
			)

			$mainHash = $Ast.FindAll({
					$args[0] -is [System.Management.Automation.Language.HashtableAst] -and
					$args[0].KeyValuePairs.Item1.Value -contains 'RootModule' -and
					$args[0].KeyValuePairs.Item1.Value -Contains 'ModuleVersion'
				}, $true)

			$entry = $mainhash.KeyValuePairs | Where-Object { $_.Item1.Value -eq $Property }
			$stringValue = switch ($Type) {
				'String' { $Value | ConvertTo-Psd1 }
				'StringArray' { , @(, @($Value)) | ConvertTo-Psd1 }
				'HashtableArray' { , @(, @($Value)) | ConvertTo-Psd1 }
			}
			$format = '{0}'
			#region Case: Key Already Exists
			if ($entry) {
				$start = $entry.Item2.Extent.StartOffset
				$end = $entry.Item2.Extent.EndOffset
			}
			#endregion Case: Key Already Exists

			#region Case: Key Does not exist
			else {
				$line = $Ast.Extent.Text -split "`n" | Where-Object { $_ -match "#\s+$Property = " }
				# Entry already exists but is commented out
				if ($line) {
					$format = "$Property = {0}"
					$index = $Ast.Extent.Text.IndexOf($line)
					$start = $index + $line.Length - $line.TrimStart().Length
					$end = $index + $line.Length
				}
				# Entry does not exist already
				else {
					$indent = ($Ast.Extent.Text -split "`n" | Where-Object { $_ -match "^\s+ModuleVersion" }) -replace '^(\s*).+$', '$1'
					$format = "$($indent)$($Property) = {0}`n"
					$start = $mainHash.Extent.EndOffset - 1
					$end = $mainHash.Extent.EndOffset - 1
				}
			}
			#endregion Case: Key Does not exist

			$newText = $Ast.Extent.Text.SubString(0,$start) + ($format -f $stringValue) + $Ast.Extent.SubString($end)
			[System.Management.Automation.Language.Parser]::ParseInput($newText, [ref]$null, [ref]$null)
		}
		#endregion Utility Functions
	}
	process {
		# If Nothing to do, do nothing
		if (-not ($Tags -or $LicenseUri -or $IconUri -or $ProjectUri -or $ReleaseNotes -or $Prerelease)) { return }

		$killIt = $ErrorActionPreference -eq 'Stop'

		$ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)

		$mainHash = $ast.FindAll({
				$args[0] -is [System.Management.Automation.Language.HashtableAst] -and
				$args[0].KeyValuePairs.Item1.Value -contains 'RootModule' -and
				$args[0].KeyValuePairs.Item1.Value -Contains 'ModuleVersion'
			}, $true)

		if (-not $mainHash) {
			Stop-PSFFunction -String 'Update-PSFModuleManifest.Error.BadManifest' -StringValues (Get-Item -Path $Path).BaseName, $Path -Cmdlet $Cmdlet -EnableException $killIt -Continue:$Continue
			return
		}
		
		#region PrivateData Content
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
			$newManifest = $ast.Extent.Text.Insert(($mainHash.Extent.EndOffset - 1), "PrivateData = $privateDataString`n")
		}
		else {
			$newManifest = $ast.Extent.Text.SubString(0, $privateDataAst.Extent.StartOffset) + $privateDataString + $ast.Extent.Text.SubString($privateDataAst.Extent.EndOffset)
		}
		#endregion PrivateData Content

		if ($PassThru) { $newManifest }
		else { $newManifest | Set-Content -Path $Path }
	}
}