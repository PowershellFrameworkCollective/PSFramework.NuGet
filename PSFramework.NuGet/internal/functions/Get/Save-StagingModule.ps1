function Save-StagingModule {
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

			$result = [PSCustomObject]@{
				Success        = $false
				Error          = $null
				ModuleName     = $Item.Name
				ModuleVersion  = $item.Version
				RepositoryName = $Repository.Name
				RepositoryType = $Repository.Type
			}

			$tempDirectory = New-PSFTempDirectory -Name StagingSub -ModuleName PSFramework.NuGet
			$param = $Item.v2Param
			# 1) Save to temp folder
			try { Save-Module @param -Path $tempDirectory @callSpecifics }
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
				$AuthenticodeCheck
			)

			Write-PSFMessage -String 'Save-StagingModule.SavingV3.Start' -StringValues $Item.Name, $Item.Version, $Repository.Name, $Repository.Type -Target $Item

			$callSpecifics = @{
				AcceptLicense = $true
				ErrorAction   = 'Stop'
				Repository    = $Repository.Name
			}
			if ($Credential) { $callSpecifics.Credential = $Credential }
			if ($SkipDependency) { $callSpecifics.SkipDependencyCheck = $true }

			$result = [PSCustomObject]@{
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
		:item foreach ($installItem in $InstallData) {
			$saveResults = foreach ($repository in $Repositories | Set-PSFObjectOrder -Property Priority, '>Type') {
				$saveResult = switch ($repository.Type) {
					V2 { Save-StagingModuleV2 -Repository $repository -Item $installItem @common }
					V3 { Save-StagingModuleV3 -Repository $repository -Item $installItem @common }
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