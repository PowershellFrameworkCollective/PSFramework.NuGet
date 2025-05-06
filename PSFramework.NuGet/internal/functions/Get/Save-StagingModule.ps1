function Save-StagingModule {
	<#
	.SYNOPSIS
		Downloads modules from a repository into a specified, local path.
	
	.DESCRIPTION
		Downloads modules from a repository into a specified, local path.
		This is used internally by Save-PSFModule to cache modules to deploy in one central location that is computer-local.
	
	.PARAMETER InstallData
		The specifics of the module to download.
		The result of the Resolve-ModuleTarget command, it contains V2/V3 specific targeting information.
	
	.PARAMETER Path
		The path where to save them to.
	
	.PARAMETER Repositories
		The repositories to contact.
		Must be repository objects as returned by Get-PSFRepository.
		Repository priority will be adhered.
	
	.PARAMETER Credential
		The Credentials to use for accessing the repositories.
	
	.PARAMETER SkipDependency
		Do not include any dependencies.
		Works with PowerShellGet V1/V2 as well.
	
	.PARAMETER AuthenticodeCheck
		Whether modules must be correctly signed by a trusted source.
		Uses "Get-PSFModuleSignature" for validation.
		Defaults to: $false
		Default can be configured under the 'PSFramework.NuGet.Install.AuthenticodeSignature.Check' setting.
	
	.PARAMETER TrustRepository
		Whether we should trust the repository installed from and NOT ask users for confirmation.
	
	.PARAMETER Cmdlet
		The $PSCmdlet variable of the calling command, used to ensure errors happen within the scope of the caller, hiding this internal helper command from the user.
	
	.EXAMPLE
		PS C:\> Save-StagingModule -InstallData $installData -Path $tempDirectory -Repositories $repositories -Cmdlet $PSCmdlet -Credential $Credential -SkipDependency:$SkipDependency -AuthenticodeCheck:$AuthenticodeCheck
	
		Downloads modules from a repository into a specified, local path.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "")]
	[CmdletBinding()]
	param (
		[object[]]
		$InstallData,
		
		[string]
		$Path,

		[object[]]
		$Repositories,

		[AllowNull()]
		[PSCredential]
		$Credential,

		[switch]
		$SkipDependency,

		[switch]
		$AuthenticodeCheck,

		[switch]
		$TrustRepository,

		$Cmdlet = $PSCmdlet
	)
	begin {
		#region Implementing Functions
		function Save-StagingModuleV2 {
			[CmdletBinding()]
			param (
				$Repository,

				$Item,

				[string]
				$Path,

				[AllowNull()]
				[PSCredential]
				$Credential,

				[switch]
				$SkipDependency,

				[switch]
				$AuthenticodeCheck
			)

			Write-PSFMessage -String 'Save-StagingModule.SavingV2.Start' -StringValues $Item.Name, $Item.Version, $Repository.Name, $Repository.Type -Target $Item

			$callSpecifics = @{
				AcceptLicense = $true
				ErrorAction   = 'Stop'
				Repository    = $Repository.Name
			}
			if ($Credential) { $callSpecifics.Credential = $Credential }
			if ($Repository.Credential) { $callSpecifics.Credential = $Repository.Credential }

			$result = [PSCustomObject]@{
				PSTypeName     = 'PSFramework.NuGet.DownloadResult'
				Success        = $false
				Error          = $null
				ModuleName     = $Item.Name
				ModuleVersion  = $item.Version
				RepositoryName = $Repository.Name
				RepositoryType = $Repository.Type
			}

			$tempDirectory = New-PSFTempDirectory -Name StagingSub -ModuleName PSFramework.NuGet
			$param = $Item.v2Param
			$actualParam = $param + $callSpecifics | ConvertTo-PSFHashtable -ReferenceCommand Save-Module

			# 1) Save to temp folder
			try { Save-Module @actualParam -Path $tempDirectory }
			catch {
				Write-PSFMessage -String 'Save-StagingModule.SavingV2.Error.Download' -StringValues $Item.Name, $Item.Version, $Repository.Name, $Repository.Type -Target $Item -Tag fail, save -ErrorRecord $_
				$result.Error = $_

				Remove-PSFTempItem -Name StagingSub -ModuleName PSFramework.NuGet
				Write-PSFMessage -String 'Save-StagingModule.SavingV2.Done' -StringValues $result.Success, $Item.Name, $Item.Version, $Repository.Name, $Repository.Type -Target $Item
				return $result
			}
			# 2) Remove redundant modules
			if ($SkipDependency) {
				# V2 Does not support saving without its dependencies coming along, so we cleanup in pre-staging
				try { Get-ChildItem -Path $tempDirectory | Where-Object Name -NE $Item.Name | Remove-Item -Force -Recurse -ErrorAction Stop }
				catch {
					Write-PSFMessage -String 'Save-StagingModule.SavingV2.Error.DependencyCleanup' -StringValues $Item.Name, $Item.Version, $Repository.Name, $Repository.Type -Target $Item -Tag fail, cleanup -ErrorRecord $_
					$result.Error = $_
	
					Remove-PSFTempItem -Name StagingSub -ModuleName PSFramework.NuGet
					Write-PSFMessage -String 'Save-StagingModule.SavingV2.Done' -StringValues $result.Success, $Item.Name, $Item.Version, $Repository.Name, $Repository.Type -Target $Item
					return $result
				}
			}
			# 3) Verify Signature
			if ($AuthenticodeCheck) {
				$signatures = foreach ($moduleBase in Get-ChildItem -Path $tempDirectory) {
					Get-PSFModuleSignature -Path (Get-Item -Path "$moduleBase\*").FullName
				}
				foreach ($signature in $signatures) {
					Write-PSFMessage -String 'Save-StagingModule.SavingV2.SignatureCheck' -StringValues $signature.Name, $signature.Version, $signature.IsSigned -Target $signature
				}

				if ($unsigned = @($signatures).Where{ -not $_.IsSigned }) {
					$result.Error = [System.Management.Automation.ErrorRecord]::new(
						[System.Exception]::new("Modules are not signed by a trusted code signer: $($unsigned.Name -join ', ')"),
						'NotTrusted',
						[System.Management.Automation.ErrorCategory]::SecurityError,
						$unsigned
					)
					Write-PSFMessage -String 'Save-StagingModule.SavingV2.Error.Unsigned' -StringValues $Item.Name, $Item.Version, $Repository.Name, $Repository.Type -Target $Item -Tag fail, signed -ErrorRecord $result.Error
					Remove-PSFTempItem -Name StagingSub -ModuleName PSFramework.NuGet
					Write-PSFMessage -String 'Save-StagingModule.SavingV2.Done' -StringValues $result.Success, $Item.Name, $Item.Version, $Repository.Name, $Repository.Type -Target $Item
					return $result
				}
			}
			# 4) Move to Staging
			try { Get-ChildItem -Path $tempDirectory | Copy-Item -Destination $Path -Recurse -Force -ErrorAction Stop }
			catch {
				Write-PSFMessage -String 'Save-StagingModule.SavingV2.Error.Transfer' -StringValues $Item.Name, $Item.Version, $Repository.Name, $Repository.Type -Target $Item -Tag fail, save -ErrorRecord $_
				$result.Error = $_

				Remove-PSFTempItem -Name StagingSub -ModuleName PSFramework.NuGet
				Write-PSFMessage -String 'Save-StagingModule.SavingV2.Done' -StringValues $result.Success, $Item.Name, $Item.Version, $Repository.Name, $Repository.Type -Target $Item
				return $result
			}

			Remove-PSFTempItem -Name StagingSub -ModuleName PSFramework.NuGet
			$result.Success = $true
			Write-PSFMessage -String 'Save-StagingModule.SavingV2.Done' -StringValues $result.Success, $Item.Name, $Item.Version, $Repository.Name, $Repository.Type -Target $Item
			$result
		}

		function Save-StagingModuleV3 {
			[CmdletBinding()]
			param (
				$Repository,

				$Item,

				[string]
				$Path,

				[AllowNull()]
				[PSCredential]
				$Credential,

				[switch]
				$SkipDependency,

				[switch]
				$AuthenticodeCheck,

				[switch]
				$TrustRepository
			)

			Write-PSFMessage -String 'Save-StagingModule.SavingV3.Start' -StringValues $Item.Name, $Item.Version, $Repository.Name, $Repository.Type -Target $Item

			$callSpecifics = @{
				ErrorAction = 'Stop'
				Repository  = $Repository.Name
			}
			if ((Get-Command Save-PSResource).Parameters.Keys -contains 'AcceptLicense') {
				$callSpecifics.AcceptLicense = $true
			}
			if ($Credential) { $callSpecifics.Credential = $Credential }
			if ($Repository.Credential) { $callSpecifics.Credential = $Repository.Credential }
			if ($SkipDependency) { $callSpecifics.SkipDependencyCheck = $true }

			$result = [PSCustomObject]@{
				PSTypeName     = 'PSFramework.NuGet.DownloadResult'
				Success        = $false
				Error          = $null
				ModuleName     = $Item.Name
				ModuleVersion  = $item.Version
				RepositoryName = $Repository.Name
				RepositoryType = $Repository.Type
			}

			$tempDirectory = New-PSFTempDirectory -Name StagingSub -ModuleName PSFramework.NuGet
			$param = $Item.v3Param
			# 1) Save to temp folder
			try { Save-PSResource @param -Path $tempDirectory @callSpecifics }
			catch {
				Write-PSFMessage -String 'Save-StagingModule.SavingV3.Error.Download' -StringValues $Item.Name, $Item.Version, $Repository.Name, $Repository.Type -Target $Item -Tag fail, save -ErrorRecord $_
				$result.Error = $_

				Remove-PSFTempItem -Name StagingSub -ModuleName PSFramework.NuGet
				Write-PSFMessage -String 'Save-StagingModule.SavingV3.Done' -StringValues $result.Success, $Item.Name, $Item.Version, $Repository.Name, $Repository.Type -Target $Item
				return $result
			}
			# 2) Verify Signature
			if ($AuthenticodeCheck) {
				$signatures = foreach ($moduleBase in Get-ChildItem -Path $tempDirectory) {
					Get-PSFModuleSignature -Path (Get-Item -Path "$moduleBase\*").FullName
				}
				foreach ($signature in $signatures) {
					Write-PSFMessage -String 'Save-StagingModule.SavingV3.SignatureCheck' -StringValues $signature.Name, $signature.Version, $signature.IsSigned -Target $signature
				}

				if ($unsigned = @($signatures).Where{ -not $_.IsSigned }) {
					$result.Error = [System.Management.Automation.ErrorRecord]::new(
						[System.Exception]::new("Modules are not signed by a trusted code signer: $($unsigned.Name -join ', ')"),
						'NotTrusted',
						[System.Management.Automation.ErrorCategory]::SecurityError,
						$unsigned
					)
					Write-PSFMessage -String 'Save-StagingModule.SavingV3.Error.Unsigned' -StringValues $Item.Name, $Item.Version, $Repository.Name, $Repository.Type -Target $Item -Tag fail, signed -ErrorRecord $result.Error
					Remove-PSFTempItem -Name StagingSub -ModuleName PSFramework.NuGet
					Write-PSFMessage -String 'Save-StagingModule.SavingV3.Done' -StringValues $result.Success, $Item.Name, $Item.Version, $Repository.Name, $Repository.Type -Target $Item
					return $result
				}
			}
			# 3) Move to Staging
			try { Get-ChildItem -Path $tempDirectory | Copy-Item -Destination $Path -Recurse -Force -ErrorAction Stop }
			catch {
				Write-PSFMessage -String 'Save-StagingModule.SavingV3.Error.Transfer' -StringValues $Item.Name, $Item.Version, $Repository.Name, $Repository.Type -Target $Item -Tag fail, save -ErrorRecord $_
				$result.Error = $_

				Remove-PSFTempItem -Name StagingSub -ModuleName PSFramework.NuGet
				Write-PSFMessage -String 'Save-StagingModule.SavingV3.Done' -StringValues $result.Success, $Item.Name, $Item.Version, $Repository.Name, $Repository.Type -Target $Item
				return $result
			}

			Remove-PSFTempItem -Name StagingSub -ModuleName PSFramework.NuGet
			$result.Success = $true
			Write-PSFMessage -String 'Save-StagingModule.SavingV3.Done' -StringValues $result.Success, $Item.Name, $Item.Version, $Repository.Name, $Repository.Type -Target $Item
			$result
		}
		#endregion Implementing Functions

		$common = @{
			SkipDependency    = $SkipDependency
			AuthenticodeCheck = $AuthenticodeCheck
			Path              = $Path
			Credential        = $Credential
		}
	}
	process {
		$null = :item foreach ($installItem in $InstallData) {
			$saveResults = foreach ($repository in $Repositories | Set-PSFObjectOrder -Property Priority, '>Type') {
				$saveResult = switch ($repository.Type) {
					V2 { Save-StagingModuleV2 -Repository $repository -Item $installItem @common }
					V3 { Save-StagingModuleV3 -Repository $repository -Item $installItem -TrustRepository:$TrustRepository @common }
					default { Stop-PSFFunction -String 'Save-StagingModule.Error.UnknownRepoType' -StringValues $repository.Type, $repository.Name -Target $repository -Cmdlet $Cmdlet -EnableException $true }
				}
				if ($saveResult.Success) { continue item }
				$saveResult
			}
			# Only reached if no repository was successful
			foreach ($result in $saveResults) {
				$Cmdlet.WriteError($result.Error)
			}
			Stop-PSFFunction -String 'Save-StagingModule.Error.SaveFailed' -StringValues $installItem.Name, $installItem.Version, (@($repository).ForEach{ '{0} ({1})' -f $_.Name, $_.Type } -join ', ') -Target $installItem -Cmdlet $Cmdlet -EnableException $true
		}
	}
}