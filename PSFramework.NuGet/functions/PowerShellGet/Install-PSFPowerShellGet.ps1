function Install-PSFPowerShellGet {
	[CmdletBinding()]
	Param (
		[ValidateSet('V2Binaries', 'V2Latest', 'V3Latest')]
		[string]
		$Type = 'V2Binaries',

		[Parameter(ValueFromPipeline = $true)]
		[PSFComputer[]]
		$ComputerName = $env:COMPUTERNAME,

		[PSCredential]
		$Credential,

		[string]
		$SourcePath = (Join-Path -Path (Get-PSFPath -Name AppData) -ChildPath 'PowerShell/PSFramework/modules/PowerShellGet'),

		[switch]
		$Offline,

		[switch]
		$NotInternal
	)
	
	begin {
		#region Functions
		function Resolve-PowerShellGet {
			[OutputType([hashtable])]
			[CmdletBinding()]
			param (
				[string]
				$Type,

				[string]
				$SourcePath,

				[switch]
				$Offline,

				[switch]
				$NotInternal
			)

			#region V2Binaries
			if ('V2Binaries' -eq $Type) {
				@{
					Type    = $Type
					NuGet   = [System.IO.File]::ReadAllBytes("$script:ModuleRoot\bin\NuGet.exe")
					PkgMgmt = [System.IO.File]::ReadAllBytes("$script:ModuleRoot\bin\Microsoft.PackageManagement.NuGetProvider.dll")
				}
				return
			}
			#endregion V2Binaries

			$internalVersion = Get-Content -Path "$script:ModuleRoot\modules\modules.json" | ConvertFrom-Json
			if ($NotInternal) { $internalVersion = @{ } }
			$sourceVersion = @{ }
			$onlineVersion = @{ }
			$sourceFile = Join-Path -Path $SourcePath -ChildPath modules.json
			if (Test-Path -Path $sourceFile) {
				$sourceVersion = Get-Content -Path $sourceFile | ConvertFrom-Json
			}

			#region Check Online
			if (-not $Offline) {
				$links = @(
					'PSGetV2'
					'PSGetV3'
					'PSPkgMgmt'
				)

				foreach ($link in $links) {
					$resolvedUrl = Resolve-AkaMsLink -Name $link
					if (-not $resolvedUrl) { continue }

					$onlineVersion[$link] = [PSCustomObject]@{
						Type     = $link
						Name     = ($resolvedUrl -split '/')[-2]
						Version  = ($resolvedUrl -split '/')[-1]
						Resolved = $resolvedUrl
						FileName = ''
					}
					$onlineVersion[$link].FileName = '{0}-{1}.zip' -f $onlineVersion[$link].Name, $onlineVersion[$link].Version
				}
			}
			#endregion Check Online
		
			$source = 'Internal'
			$typeTag = switch ($Type) {
				'V2Latest' { 'PSGetV2' }
				'V3Latest' { 'PSGetV3' }
			}
			if ($sourceVersion.$typeTag.Version -and $sourceVersion.$typeTag.Version -ne $internalVersion.$typeTag.Version) {
				$source = 'Source'
			}
			if ($onlineVersion.$typeTag.Version -and $onlineVersion.$typeTag.Version -ne $internalVersion.$typeTag.Version) {
				$source = 'Online'
			}
			
			# If online version is newer than internal, download to appdata as cached version
			if ('Online' -eq $source) {
				if (-not (Test-Path -Path $SourcePath)) { $null = New-Item -Path $SourcePath -ItemType Directory -Force }
				Save-PSFPowerShellGet -Path $SourcePath # This can never happen if the user specified a path, so no risk of overwriting.
			}

			$rootPath = switch ($source) {
				Internal { "$script:ModuleRoot\modules" }
				Source { $SourcePath }
				Online { $SourcePath }
			}

			$actualConfiguration = Import-PSFPowerShellDataFile -Path (Join-Path -Path $rootPath -ChildPath 'modules.json')
			$data = @{
				Type = $Type
				Config = $actualConfiguration
			}
			switch ($Type) {
				'V2Latest' {
					$data.PSGetV2 = [System.IO.File]::ReadAllBytes((Join-Path -Path $rootPath -ChildPath $actualConfiguration.PSGetV2.FileName))
					$data.PSPkgMgmt = [System.IO.File]::ReadAllBytes((Join-Path -Path $rootPath -ChildPath $actualConfiguration.PSPkgMgmt.FileName))
				}
				'V3Latest' {
					$data.PSGetV3 = [System.IO.File]::ReadAllBytes((Join-Path -Path $rootPath -ChildPath $actualConfiguration.PSGetV3.FileName))
				}
			}
			$data
		}
		#endregion Functions

		#region Actual Code
		$code = {
			param (
				$Data
			)

			#region Functions
			function Install-ZipModule {
				[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
				[CmdletBinding()]
				param (
					$Config,

					[string]
					$ModulesFolder,

					[string]
					$TempFolder
				)

				$modulePath = Join-Path -Path $ModulesFolder -ChildPath ('{0}/{1}' -f $Config.Name, ($Config.Version -replace '\-.+$'))

				if (Test-Path -Path $modulePath) { return }

				$null = New-Item -Path $modulePath -ItemType Directory -Force
				Expand-Archive -Path (Join-Path -Path $TempFolder -ChildPath $Config.FileName) -DestinationPath $modulePath
			}
			#endregion Functions

			## Create temporary folder
			$tempFolder = (New-Item -Path $env:TEMP -Name "PSGet-$(Get-Random)" -ItemType Directory -Force).FullName

			#region Write binary data
			if ($Data.NuGet) {
				[System.IO.File]::WriteAllBytes((Join-Path -Path $tempFolder -ChildPath 'NuGet.exe'), $Data.NuGet)
			}
			if ($Data.PkgMgmt) {
				[System.IO.File]::WriteAllBytes((Join-Path -Path $tempFolder -ChildPath 'Microsoft.PackageManagement.NuGetProvider.dll'), $Data.PkgMgmt)
			}
			if ($Data.PSGetV2) {
				[System.IO.File]::WriteAllBytes((Join-Path -Path $tempFolder -ChildPath $Data.Config.PSGetV2.FileName), $Data.PSGetV2)
			}
			if ($Data.PSGetV3) {
				[System.IO.File]::WriteAllBytes((Join-Path -Path $tempFolder -ChildPath $Data.Config.PSGetV3.FileName), $Data.PSGetV3)
			}
			if ($Data.PSPkgMgmt) {
				[System.IO.File]::WriteAllBytes((Join-Path -Path $tempFolder -ChildPath $Data.Config.PSPkgMgmt.FileName), $Data.PSPkgMgmt)
			}
			#endregion Write binary data

			#region Copy to destination
			$isOnWindows = $PSVersionTable.PSVersion.Major -lt 6 -or $isWindows
			switch ($Data.Type) {
				#region V2 Bootstrap
				V2Binaries {
					if ($isOnWindows) {
						if (-not (Test-Path -Path "$env:ProgramFiles\Microsoft\Windows\PowerShell\PowerShellGet")) {
							$null = New-Item -Path "$env:ProgramFiles\Microsoft\Windows\PowerShell\PowerShellGet" -ItemType Directory -Force
						}
						Copy-Item -Path (Join-Path -Path $tempFolder -ChildPath 'NuGet.exe') -Destination "$env:ProgramFiles\Microsoft\Windows\PowerShell\PowerShellGet" -Force
						if (-not (Test-Path -Path "$env:ProgramFiles\PackageManagement\ProviderAssemblies\nuget\2.8.5.208")) {
							$null = New-Item -Path "$env:ProgramFiles\PackageManagement\ProviderAssemblies\nuget\2.8.5.208" -ItemType Directory -Force
						}
						Copy-Item -Path (Join-Path -Path $tempFolder -ChildPath 'Microsoft.PackageManagement.NuGetProvider.dll') -Destination "$env:ProgramFiles\PackageManagement\ProviderAssemblies\nuget\2.8.5.208" -Force
					}
					else {
						Copy-Item -Path (Join-Path -Path $tempFolder -ChildPath 'NuGet.exe') -Destination "$HOME/.config/powershell/powershellget" -Force
					}
				}
				#endregion V2 Bootstrap

				#region V2 Latest
				V2Latest {
					$modulesFolder = "$env:ProgramFiles\WindowsPowerShell\modules"
					if (-not $isOnWindows) { $modulesFolder = "/usr/local/share/powershell/Modules" }

					Install-ZipModule -Config $data.Config.PSGetV2 -ModulesFolder $modulesFolder -TempFolder $tempFolder
					Install-ZipModule -Config $data.Config.PSPkgMgmt -ModulesFolder $modulesFolder -TempFolder $tempFolder
				}
				#endregion V2 Latest

				#region V3 Latest
				V3Latest {
					$modulesFolder = "$env:ProgramFiles\WindowsPowerShell\modules"
					if (-not $isOnWindows) { $modulesFolder = "/usr/local/share/powershell/Modules" }

					Install-ZipModule -Config $data.Config.PSGetV3 -ModulesFolder $modulesFolder -TempFolder $tempFolder
				}
				#endregion V3 Latest
			}
			#endregion Copy to destination

			## Cleanup
			Remove-Item -Path $tempFolder -Recurse -Force
		}
		#endregion Actual Code

		#region Resolve Source Configuration
		$stayOffline = $Offline
		$useInternal = -not $NotInternal
		if ($PSBoundParameters.Keys -contains 'SourcePath') {
			if ($PSBoundParameters.Keys -notcontains 'Offline') {
				$stayOffline = $true
			}
			if ($PSBoundParameters.Keys -notcontains 'NotInternal') {
				$useInternal = $false
			}
		}
		#endregion Resolve Source Configuration
	}
	process {
		# If installing the latest V2 modules, you'll also want the binaries needed
		if ('V2Latest' -eq $Type) {
			Install-PSFPowerShellGet -Type V2Binaries -ComputerName $ComputerName -Credential $Credential
		}

		# Get Binaries / Modules to deploy
		$binaries = Resolve-PowerShellGet -Type $Type -Offline:$stayOffline -SourcePath $SourcePath -NotInternal:$useInternal

		# Execute Deployment
		Invoke-PSFCommand -ComputerName $ComputerName -ScriptBlock $code -Credential $Credential -ArgumentList $binaries
	}
	end {
		Search-PSFPowerShellGet
	}
}
