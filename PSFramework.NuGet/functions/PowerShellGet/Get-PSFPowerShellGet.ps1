function Get-PSFPowerShellGet {
	<#
	.SYNOPSIS
		Returns the availability state for PowerShellGet.
	
	.DESCRIPTION
		Returns the availability state for PowerShellGet.
		Will verify, whether required prerequisites for module installation or publishing exist
		for v1/v2 versions of PowerShellGet.
		It will only check for the all users configuration, ignoring binaries stored in appdata.
	
	.PARAMETER ComputerName
		The computer to scan.
		Defaults to localhost.
	
	.PARAMETER Credential
		Credentials to use for the connection to the remote computers.
	
	.EXAMPLE
		PS C:\> Get-PSFPowerShellGet
		
		Returns, what the local PowerShellGet configuration is like.
	#>
	[CmdletBinding()]
	Param (
		[Parameter(ValueFromPipeline = $true)]
		[PSFComputer[]]
		$ComputerName = $env:COMPUTERNAME,

		[PSCredential]
		$Credential
	)
	
	begin {
		$code = {
			$modules = Get-Module -Name PowerShellGet -ListAvailable
			$modulesV3 = Get-Module -Name Microsoft.PowerShell.PSResourceGet -ListAvailable

			$isOnWindows = $PSVersionTable.PSVersion.Major -lt 6 -or $isWindows
			if ($isOnWindows) {
				$nugetPath = "$env:ProgramFiles\Microsoft\Windows\PowerShell\PowerShellGet\NuGet.exe"
				$v2CanInstall = Test-Path -Path "$env:ProgramFiles\PackageManagement\ProviderAssemblies\nuget\2.8.5.208\Microsoft.PackageManagement.NuGetProvider.dll"
			}
			else {
				$nugetPath = "$HOME/.config/powershell/powershellget/NuGet.exe"
				$v2CanInstall = $true
			}
			if ($modules | Where-Object { $_.Version.Major -lt 3 -and $_.Version -ge ([version]'2.5.0') }) {
				$v2CanInstall = $true
			}

			[PSCustomObject]@{
				PSTypeName   = 'PSFramework.NuGet.GetReport'
				ComputerName = $env:COMPUTERNAME
				V2           = ($modules | Where-Object { $_.Version.Major -lt 3 }) -as [bool]
				V3           = $modulesV3 -as [bool]
				V2CanInstall = $v2CanInstall
				V2CanPublish = Test-Path -Path $nugetPath
				Modules      = $modules
			}
		}
	}
	process {
		Invoke-PSFCommand -ComputerName $ComputerName -ScriptBlock $code -Credential $Credential
	}
}