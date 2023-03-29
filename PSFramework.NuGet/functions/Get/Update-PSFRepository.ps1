function Update-PSFRepository {
	<#
	.SYNOPSIS
		Executes configured repository settings.
	
	.DESCRIPTION
		Executes configured repository settings.
		Using configuration settings - for example applied per GPO or configuration file - it is possible to define intended repositories.

		The configuration settings must be named as 'PSFramework.NuGet.Repositories.<Repository Name>.<Setting>'

		Available settings:
		- Uri: Url or filesystem path to the repository. Used for both install and publish.
		- Priority: Priority of a PowerShellGet V3 Repository. Numeric value, determines repository precedence
		- Type: What kind of PowerShellGet version to apply the configuration to. Details on the options below. Defaults to 'Any'.
		- Trusted: Whether the repository should be trusted. Can be set to 0, 1, $false or $true. Defaults to $true.
		- Present: Whether the repository should exist at all. Can be set to 0, 1, $false or $true. Defaults to $true.
		           Allows creating delete orders. Does not differentiate between V2 & V3
	   
	    Supported "Type" settings to handle different PowerShellGet versions:
		- Any: Will register as V3 if available, otherwise V2. Will not update to V3 if already on V2.
		- Update: Will register under highest version available, upgrading from older versions if already available on old versions
		- All: Will register on ALL available versions
		- V2: Will only register on V2. V3 - if present and configured - will be unregistered.
		- V2Preferred: Will only register on V2. If V2 does not exist, existing V3 repositories will be allowed.
		- V3: Will only register on V3. If V2 is present, it will be unregistered, irrespective of whether V3 is available.
	
	.EXAMPLE
		PS C:\> Update-PSFRepository
		
		Executes configured repository settings, creating, updating and deleting repositories as defined.
	#>
	[CmdletBinding()]
	Param (
	
	)
	
	begin {
		#region Functions
		function Compare-Repository {
			[CmdletBinding()]
			param (
				$Actual,
				$Configured
			)

			foreach ($configuredRepo in $Configured) {
				$matching = $Actual | Where-Object Name -EQ $configuredRepo._Name
				$shouldExist = -not ($configuredRepo.PSObject.Properties.Name -contains 'Present' -and -not $configuredRepo.Present)

				$mayBeV2 = $configuredRepo.Type -in 'Any', 'Update', 'All', 'V2', 'V2Preferred'
				if ('Update' -eq $configuredRepo.Type -and $script:psget.V3) { $mayBeV2 = $false }
				$mustBeV2 = $configuredRepo.Type -in 'All', 'V2'
				$mayBeV3 = $configuredRepo.Type -in 'Any', 'Update', 'All', 'V3', 'V2Preferred'
				if ('V2Preferred' -eq $configuredRepo.Type -and $script:psget.V2) { $mayBeV3 = $false }
				$mustBeV3 = $configuredRepo.Type -in 'Update', 'All', 'V3'

				# Case: Should not exist and does not
				if (-not $shouldExist -and -not $matching) {
					continue
				}

				#region Deletion
				foreach ($matchingRepo in $matching) {
					if (
						# Should exist
						$shouldExist -and
						(
							$matchingRepo.Type -eq 'V2' -and $mayBeV2 -or
							$matchingRepo.Type -eq 'V3' -and $mayBeV3
						)
					) {
						continue
					}

					[PSCustomObject]@{
						Type       = 'Delete'
						Configured = $configuredRepo
						Actual     = $matchingRepo
						Changes    = @{ }
					}
				}
				if (-not $shouldExist) { continue }
				#endregion Deletion

				#region Creation
				# Case: Should exist but does not
				if ($shouldExist -and -not $matching) {
					[PSCustomObject]@{
						Type       = 'Create'
						Configured = $configuredRepo
						Actual     = $null
						Changes    = @{ }
					}
					continue
				}

				# Case: Must exist on V2 but does not
				if ($mustBeV2 -and $matching.Type -notcontains 'V2' -and $script:psget.V2) {
					[PSCustomObject]@{
						Type       = 'Create'
						Configured = $configuredRepo
						Actual     = $matching
						Changes    = @{ }
					}
				}

				# Case: Must exist on V3 but does not
				if ($mustBeV3 -and $matching.Type -notcontains 'V3' -and $script:psget.V3) {
					[PSCustomObject]@{
						Type       = 'Create'
						Configured = $configuredRepo
						Actual     = $matching
						Changes    = @{ }
					}
				}

				# If there is no matching, existing repository, there is no need to update
				if (-not $matching) { continue }
				#endregion Creation

				#region Update
				foreach ($matchingRepo in $matching) {
					$intendedUri = $configuredRepo.Uri
					if ('V2' -eq $matchingRepo.Type) { $intendedUri = $intendedUri -replace 'v3/index.json$', 'v2' }
					$trusted = $configuredRepo.Trusted -as [int]
					if ($null -eq $trusted -and $configuredRepo.Trusted -in 'True', 'False') {
						$trusted = $configuredRepo.Trusted -eq 'True'
					}
					if ($null -eq $trusted) { $trusted = $true }
					
					$changes = @{ }
					if ($matchingRepo.Uri -ne $intendedUri) { $changes.Uri = $intendedUri }
					if ($matchingRepo.Trusted -ne $trusted) { $changes.Trusted = $trusted -as [bool] }
					if (
						$configuredRepo.Priority -and
						$matchingRepo.Type -ne 'V2' -and
						$matchingRepo.Priority -ne $configuredRepo.Priority
					) {
						$changes.Trusted = $configuredRepo.Priority
					}

					if ($changes.Count -eq 0) { continue }

					[PSCustomObject]@{
						Type       = 'Update'
						Configured = $configuredRepo
						Actual     = $matchingRepo
						Changes    = $changes
					}
				}
				#endregion Update
			}
		}
		
		function New-Repository {
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
			[CmdletBinding()]
			param (
				$Change
			)


		}
		#endregion Functions
	}
	process {
		$repositories = Get-PSFRepository
		$configuredRepositories = Select-PSFConfig -FullName PSFramework.NuGet.Repositories.* -Depth 3
		$changes = Compare-Repository -Actual $repositories -Configured $configuredRepositories
		foreach ($change in $changes) {
			switch ($change.Type) {
				'Create' { New-Repository -Change $change }
				'Delete' { Remove-Repository -Change $change }
				'Update' { Set-Repository -Change $change }
			}
		}
	}
}