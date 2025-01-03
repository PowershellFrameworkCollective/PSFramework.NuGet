function Enable-ModuleCommand {
	<#
	.SYNOPSIS
		Re-Enables a command that was previously disabled.
	
	.DESCRIPTION
		Re-Enables a command that was previously disabled.
		Use Disable-ModuleCommand to disable/override a command.
	
	.PARAMETER Name
		Name of the command to restore.
	
	.PARAMETER ModuleName
		Name of the module the command is from.
	
	.EXAMPLE
		PS C:\> Enable-ModuleCommand -Name 'Get-ModuleDependencies' -ModuleName 'PowerShellGet'

		Enables the command Get-ModuleDependencies from the module PowerShellGet
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Name,

		[Parameter(Mandatory = $true)]
		[string]
		$ModuleName
	)
	process {
		Import-Module $ModuleName -Verbose:$False
		$module = Get-Module -Name $ModuleName

		$internal = [PSFramework.Utility.UtilityHost]::GetPrivateProperty('Internal', $module.SessionState)
		$mscope = [PSFramework.Utility.UtilityHost]::GetPrivateProperty('ModuleScope', $internal)
		[PSFramework.Utility.UtilityHost]::InvokePrivateMethod("RemoveAlias", $mscope, @($Name, $true))
	}
}