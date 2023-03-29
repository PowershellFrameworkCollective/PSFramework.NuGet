param (
	$WorkingDirectory
)

#region Handle Working Directory Defaults
if (-not $WorkingDirectory)
{
	if ($env:RELEASE_PRIMARYARTIFACTSOURCEALIAS)
	{
		$WorkingDirectory = Join-Path -Path $env:SYSTEM_DEFAULTWORKINGDIRECTORY -ChildPath $env:RELEASE_PRIMARYARTIFACTSOURCEALIAS
	}
	else { $WorkingDirectory = $env:SYSTEM_DEFAULTWORKINGDIRECTORY }
}
if (-not $WorkingDirectory) { $WorkingDirectory = Split-Path $PSScriptRoot }
#endregion Handle Working Directory Defaults

$publishDir = Join-Path -Path $WorkingDirectory -ChildPath publish | Get-Item

Import-Module "$WorkingDirectory\PSFramework.NuGet\PSFramework.NuGet.psd1"
Save-PSFPowerShellGet -Path "$($publishDir.FullName)\PSFramework.NuGet\modules"