function Get-PSFModuleSignature {
	<#
	.SYNOPSIS
		Verifies, whether a module is properly signed.
	
	.DESCRIPTION
		Verifies, whether a module is properly signed.
		Iterates over every module file and verifies its signature.

		The result reports:
		- Overall signing status
		- Signatures not Timestamped count
		- Status Summary
		- Subject of signing certs summary
		- Issuer of signing certs summary

		A module should be considered signed, when ...
		- the over signing status is valid
		- the subjects are expected (A microsoft module being signed by a microsoft code signing cert, etc.)
		- the issuer CAs are expected (A microsoft module being signed by a cert issued by Microsoft, etc.)
	
	.PARAMETER Path
		Path to the module(s) to scan.
		Should be the path to either a module-root or a psd1 file.
	
	.EXAMPLE
		PS C:\> Get-PSFModuleSignature -Path .
		
		Returns, whether the module in the current path is signed.

	.EXAMPLE
		PS C:\> Get-PSFModuleSignature -Path \\contoso.com\it\coding\modules\ContosoTools

		Verifies the code signing of the module stored in \\contoso.com\it\coding\modules\ContosoTools

	.EXAMPLE
		PS C:\> Get-Module | Get-PSFModuleSignature

		Verifies for each currently loaded module, whether they are signed.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('ModuleBase', 'FullName')]
		[string[]]
		$Path
	)
	begin {
		function Resolve-ModulePath {
			[CmdletBinding()]
			param (
				[string[]]
				$Path,

				$Cmdlet
			)

			foreach ($pathItem in $Path) {
				try { $resolvedPaths = Resolve-Path $pathItem }
				catch {
					$record = [System.Management.Automation.ErrorRecord]::new(
						[Exception]::new("Path not found: $pathItem", $_.Exception),
						"InvalidPath",
						[System.Management.Automation.ErrorCategory]::InvalidArgument,
						$pathItem
					)
					$Cmdlet.WriteError($record)
					continue
				}

				foreach ($resolvedPath in $resolvedPaths) {
					$item = Get-Item -LiteralPath $resolvedPath
					if ($item.PSIsContainer) {
						$manifests = Get-ChildItem -LiteralPath $item.FullName -Filter *.psd1 -Recurse -ErrorAction SilentlyContinue
						if (-not $manifests) {
							$record = [System.Management.Automation.ErrorRecord]::new(
								[Exception]::new("No module found in: $resolvedPath (resolved from $pathItem)"),
								"ObjectNotFound",
								[System.Management.Automation.ErrorCategory]::InvalidArgument,
								$pathItem
							)
							$Cmdlet.WriteError($record)
							continue
						}

						foreach ($manifest in $manifests) {
							$manifest.Directory.FullName
						}
						continue
					}

					if ($item.Extension -in '.psd1', 'psm1') {
						$item.Directory.FullName
						continue
					}
					if (Get-Item -Path "$($item.Directory.FullName)\*.psd1") {
						$item.Directory.FullName
						continue
					}

					$record = [System.Management.Automation.ErrorRecord]::new(
						[Exception]::new("Unexpected file: $resolvedPaht from $pathItem"),
						"UnexpectedPath",
						[System.Management.Automation.ErrorCategory]::InvalidArgument,
						$pathItem
					)
					$Cmdlet.WriteError($record)
				}
			}
		}
		
		function Get-ModuleSignatureInternal {
			[CmdletBinding()]
			param (
				[Parameter(Mandatory = $true)]
				[string]
				$Path
			)

			$signatureStatus = Get-ChildItem -LiteralPath $Path -Recurse -File | ForEach-Object {
				$currentItem = $_.FullName
				try { Get-AuthenticodeSignature -LiteralPath $currentItem }
				catch {
					[PSCustomObject]@{
						PSTypeName             = 'System.Management.Automation.Signature'
						SignerCertificate      = $null
						TimeStamperCertificate = $null
						Status                 = 'AccessError'
						StatusMessage          = $_
						Path                   = $currentItem
						SignatureType          = $null
						IsOSBinary             = $false
					}
				}
			}

			$manifest = Get-ChildItem -LiteralPath $Path -Filter *.psd1 | Select-Object -First 1
			$manifestData = @{}
			if ($manifest) {
				$manifestData = Import-PowerShellDataFile -LiteralPath $manifest.FullName
			}

			[PSCustomObject]@{
				ModuleBase       = $Path
				Name             = $manifest.BaseName
				Version          = $manifestData.ModuleVersion
				IsSigned         = -not @($signatureStatus).Where{ $_.Status -notin 'Valid', 'UnknownError' }
				FileCount        = @($signatureStatus).Count
				NoTimestampCount = @($signatureStatus).Where{ $_.SignerCertificate -and -not $_.TimeStamperCertificate }.Count
				ByStatus         = ConvertTo-SigningSummary -Results $signatureStatus -Type Status
				ByIssuer         = ConvertTo-SigningSummary -Results $signatureStatus -Type Issuer
				BySubject        = ConvertTo-SigningSummary -Results $signatureStatus -Type Subject
				Signatures       = $signatureStatus
			}
		}
		function ConvertTo-SigningSummary {
			[CmdletBinding()]
			param (
				[AllowEmptyCollection()]
				$Results,

				[Parameter(Mandatory = $true)]
				[ValidateSet('Issuer', 'Subject', 'Status')]
				[string]
				$Type
			)

			$groupBy = @{
				Issuer  = { $_.SignerCertificate.Issuer }
				Subject = { $_.SignerCertificate.Subject }
				Status  = 'Status'
			}

			$groups = $Results | Group-Object $groupBy[$Type]
			$hash = @{ }
			foreach ($group in $groups) {
				$hash[$group.Name] = $group.Group
			}
			$entry = [PSCustomObject]@{
				TotalCount = @($Results).Count
				GroupCount = @($groups).Count
				Results    = $hash
			}
			Add-Member -InputObject $entry -MemberType ScriptMethod -Name ToString -Force -Value {
				$lines = foreach ($pair in $this.Results.GetEnumerator()) {
					if (-not $pair.Key) { continue }
					if ($pair.Key -eq 'UnknownError') { '{0}: {1} (Usually: File format that cannot be signed)' -f $pair.Value.Count, $pair.Key }
					else { '{0}: {1}' -f $pair.Value.Count, $pair.Key }
				}
				$lines -join "`n"
			}
			$entry
		}
	}
	process {
		foreach ($inputPath in Resolve-ModulePath -Path $Path -Cmdlet $PSCmdlet | Sort-Object -Unique) {
			Get-ModuleSignatureInternal -Path $inputPath
		}
	}
}