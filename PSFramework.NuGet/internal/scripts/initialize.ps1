# Load what PowerShellGet versions are available
Search-PSFPowerShellGet

# Ensure all configured repositories exist, and all unintended repositories are gone
Update-PSFRepository

# Auto-Bootstrap Local GetV2 on Windows
if (
	($PSVersionTable.PSVersion.Major -lt 5 -or $IsWindows) -and
	$env:LOCALAPPDATA -and
	(-not (Test-Path "$env:LOCALAPPDATA\PackageManagement\ProviderAssemblies\nuget\2.8.5.208\Microsoft.PackageManagement.NuGetProvider.dll")) -and
	(Get-PSFConfigValue -FullName 'PSFramework.NuGet.LocalBootstrap')
) {
	$null = New-Item -Path "$env:LOCALAPPDATA\PackageManagement\ProviderAssemblies\nuget\2.8.5.208" -ItemType Directory -Force -ErrorAction SilentlyContinue
	Copy-Item -Path "$script:ModuleRoot\bin\Microsoft.PackageManagement.NuGetProvider.dll" -Destination "$env:LOCALAPPDATA\PackageManagement\ProviderAssemblies\nuget\2.8.5.208" -ErrorAction SilentlyContinue
}