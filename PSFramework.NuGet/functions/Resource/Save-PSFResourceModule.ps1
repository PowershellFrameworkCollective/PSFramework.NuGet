function Save-PSFResourceModule {
	<#
	.SYNOPSIS
	Short description
	
	.DESCRIPTION
	Long description
	
	.PARAMETER Name
		Name of the module to download.
	
	.PARAMETER Version
		Version constrains for the resource to save.
		Will use the latest version available within the limits.
		Examples:
		- "1.0.0": EXACTLY this one version
		- "1.0.0-1.999.999": Any version between the two limits (including the limit values)
		- "[1.0.0-2.0.0)": Any version greater or equal to 1.0.0 but less than 2.0.0
		- "2.3.0-": Any version greater or equal to 2.3.0.

		Supported Syntax:
		<Prefix><Version><Connector><Version><Suffix>

		Prefix: "[" (-ge) or "(" (-gt) or nothing (-ge)
		Version: A valid version of 2-4 elements or nothing
		Connector: A "," or a "-"
		Suffix: "]" (-le) or ")" (-lt) or nothing (-le)
	
	.PARAMETER Prerelease
		Whether to include prerelease versions in the potential results.
	
	.PARAMETER Path
		Where to store the resource.
	
	.PARAMETER SkipDependency
		Do not include any dependencies.
		Works with PowerShellGet V1/V2 as well.
	
	.PARAMETER AuthenticodeCheck
		Whether resource modules must be correctly signed by a trusted source.
		Uses "Get-PSFModuleSignature" for validation.
		Defaults to: $false
		Default can be configured under the 'PSFramework.NuGet.Install.AuthenticodeSignature.Check' setting.
	
	.PARAMETER Force
		Overwrite files and folders that already exist in the target path.
		By default it will skip modules that do already exist in the target path.
	
	.PARAMETER Credential
		The credentials to use for connecting to the Repository.
	
	.PARAMETER Repository
		Repositories to install from. Respects the priority order of repositories.
		See Get-PSFRepository for available repositories (and their priority).
		Lower numbers are installed from first.
	
	.PARAMETER TrustRepository
		Whether we should trust the repository installed from and NOT ask users for confirmation.
	
	.PARAMETER Type
		What type of repository to download from.
		V2 uses classic Save-Module.
		V3 uses Save-PSResource.
		Availability depends on the installed PSGet module versions and configured repositories.
		Use Install-PSFPowerShellGet to deploy the latest versions of the package modules.

		Only the version on the local computer matters, even when deploying to remote computers.
	
	.PARAMETER InputObject
		The resource module to install.
		Takes the output of Get-Module, Find-Module, Find-PSResource and Find-PSFModule, to specify the exact version and name of the resource module.
		Even when providing a locally available version, the resource module will still be downloaded from the repositories chosen.

	.PARAMETER WhatIf
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
	
	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.
	
	.EXAMPLE
		PS C:\> Save-PSFResourceModule -Name Psmd.Templates.MiniModule -Path .

		Downloads the resource module "Psmd.Templates.MiniModule" and extracts its resources into the current path.
	#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	Param (
		[Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByName')]
		[string[]]
		$Name,

		[Parameter(Mandatory = $true, Position = 1)]
		[PSFDirectory]
		$Path,

		[PsfArgumentCompleter('PSFramework.NuGet.Repository')]
		[string[]]
		$Repository = ((Get-PSFrepository).Name | Sort-Object -Unique),

		[Parameter(ParameterSetName = 'ByName')]
		[string]
		$Version,

		[Parameter(ParameterSetName = 'ByName')]
		[switch]
		$Prerelease,

		[switch]
		$SkipDependency,

		[switch]
		$AuthenticodeCheck = (Get-PSFConfigValue -FullName 'PSFramework.NuGet.Install.AuthenticodeSignature.Check'),

		[switch]
		$Force,

		[PSCredential]
		$Credential,

		[switch]
		$TrustRepository,

		[ValidateSet('All', 'V2', 'V3')]
		[string]
		$Type = 'All',

		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'ByObject')]
		[object[]]
		$InputObject
	)
	
	begin {
		$killIt = $ErrorActionPreference -eq 'Stop'
	}
	process {
		$tempDirectory = New-PSFTempDirectory -ModuleName 'PSFramework.NuGet' -Name ResourceModule
		try {
			$saveParam = $PSBoundParameters | ConvertTo-PSFHashtable -ReferenceCommand Save-PSFModule -Exclude Path, ErrorAction
			Invoke-PSFProtectedCommand -ActionString 'Save-PSFResourceModule.Downloading' -ActionStringValues ($Name -join ', ') -ScriptBlock {
				$null = Save-PSFModule @saveParam -Path $tempDirectory -ErrorAction Stop -WhatIf:$false -Confirm:$false
			} -PSCmdlet $PSCmdlet -EnableException $killIt -WhatIf:$false -Confirm:$false
			if (Test-PSFFunctionInterrupt) { return }

			foreach ($pathEntry in $Path) {
				foreach ($module in Get-ChildItem -Path $tempDirectory) {
					foreach ($versionFolder in Get-ChildItem -LiteralPath $module.FullName) {
						$dataPath = Join-Path -Path $versionFolder.FullName -ChildPath 'Resources'
						if (-not (Test-Path -Path $dataPath)) {
							Write-PSFMessage -String 'Save-PSFResourceModule.Skipping.InvalidResource' -StringValues $module.Name, $versionFolder.Name
							continue
						}
						if (-not $PSCmdlet.ShouldProcess("$($module.Name) ($($versionFolder.Name))", "Deploy to $pathEntry")) {
							continue
						}

						ConvertFrom-TransportFile -Path $dataPath

						foreach ($item in Get-ChildItem -LiteralPath $dataPath) {
							$targetPath = Join-Path -Path $pathEntry -ChildPath $item.Name
							if (-not $Force -and (Test-path -Path $targetPath)) {
								Write-PSFMessage -String 'Save-PSFResourceModule.Skipping.AlreadyExists' -StringValues $module.Name, $versionFolder.Name, $item.Name, $pathEntry
								continue
							}

							Invoke-PSFProtectedCommand -ActionString 'Save-PSFResourceModule.Deploying' -ActionStringValues $module.Name, $versionFolder.Name, $item.Name, $pathEntry -ScriptBlock {
								Move-Item -LiteralPath $item.FullName -Destination $pathEntry -Force -ErrorAction Stop -Confirm:$false -WhatIf:$false
							} -Target $item.Name -PSCmdlet $PSCmdlet -EnableException $killIt -Continue -Confirm:$false -WhatIf:$false
						}
					}
				}
			}
		}
		finally {
			Remove-PSFTempItem -ModuleName 'PSFramework.NuGet' -Name ResourceModule
		}
	}
}