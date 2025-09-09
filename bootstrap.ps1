<#
.SYNOPSIS
	Installs all that is needed to run PSFramework.NuGet without using the PowerShellGet tools.

.DESCRIPTION
	Installs all that is needed to run PSFramework.NuGet without using the PowerShellGet tools.

.EXAMPLE
	PS C:\> .\bootstrap.ps1

	Installs all that is needed to run PSFramework.NuGet without using the PowerShellGet tools.

.EXAMPLE
	PS C:\> Iwr https://raw.githubusercontent.com/PowershellFrameworkCollective/PSFramework.NuGet/refs/heads/master/bootstrap.ps1 | iex

	This one-liner will download the script into memory and then execute it directly, enabling PowerShell package management on the local computer.
#>
[CmdletBinding()]
param (
	
)

$ErrorActionPreference = 'Stop'
trap {
	Write-Warning "Script failed: $_"
	throw $_
}

#region Functions
function Find-GalleryModule {
	[CmdletBinding()]
	param (
		[string[]]
		$Name
	)

	foreach ($moduleName in $Name) {
		$page = Invoke-WebRequest "https://www.powershellgallery.com/packages/$moduleName" -UseBasicParsing
		$versions = $page.Links | Where-Object href -Match "^/packages/$moduleName/\d+(\.\d+){1,3}$"
		foreach ($version in $versions) {
			$null = $version.href -match '/(\d+(\.\d+){1,3})$'
			Add-Member -InputObject $version -MemberType NoteProperty -Name Version -Value ($matches.1 -as [version]) -Force
		}

		$latest = $versions | Sort-Object Version -Descending | Select-Object -First 1

		[PSCustomObject]@{
			Name    = $moduleName
			Version = $latest.Version
			Link    = 'https://cdn.powershellgallery.com/packages/{0}.{1}.nupkg' -f $moduleName.ToLower(), $latest.Version
		}
	}
}

function Install-GalleryModule {
	[CmdletBinding()]
	param (
		$Module
	)

	Write-Host "Installing: $($Module.Name) ($($Module.Version))"

	trap {
		Write-Host "  Failed: $_" -ForegroundColor Red -BackgroundColor Black
		return
	}

	# Resolve target path and skip if not needed
	$modulePath = $env:PSModulePath -split ';' | Where-Object { $_ -match '\\Documents\\' } | Select-Object -First 1
	if (-not $modulePath) { $modulePath = $env:PSModulePath -split ';' | Select-Object -First 1 }
	$moduleRoot = Join-Path -Path $modulePath -ChildPath "$($Module.Name)/$($Module.Version)"
	if (Test-Path -Path $moduleRoot) {
		Write-Host "  $($Module.Name) already installed, skipping"
		return
	}

	$ProgressPreference = 'SilentlyContinue'
	$staging = New-Item -Path $env:TEMP -Name "PSMS-$(Get-Random)" -ItemType Directory
	Invoke-WebRequest -Uri $Module.Link -OutFile "$($staging.FullName)\$($Module.Name).zip" -ErrorAction Stop
	Expand-Archive -Path "$($staging.FullName)\$($Module.Name).zip" -DestinationPath $staging.FullName -ErrorAction Stop
	
	# Remove undesired parts
	Remove-Item -Path "$($staging.FullName)\$($Module.Name).zip"
	Remove-Item -Path "$($staging.FullName)\$($Module.Name).nuspec"
	Remove-Item -LiteralPath "$($staging.FullName)\[Content_Types].xml"
	Remove-Item -Path "$($staging.FullName)\_rels" -Recurse -Force
	Remove-Item -Path "$($staging.FullName)\package" -Recurse -Force

	# Deploy to Documents
	$null = New-Item -Path $moduleRoot -ItemType Directory -Force
	Move-Item -Path "$($staging.FullName)\*" -Destination $moduleRoot -Force -ErrorAction Stop
	Write-Host "  Successfully completed" -ForegroundColor Green -BackgroundColor Black
	
	Remove-Item -Path $staging -ErrorAction SilentlyContinue -Force -Recurse
}
#endregion Functions

$modules = Find-GalleryModule -Name PSFramework, ConvertToPSD1, PSFramework.NuGet
foreach ($module in $modules) {
	Install-GalleryModule -Module $module
}