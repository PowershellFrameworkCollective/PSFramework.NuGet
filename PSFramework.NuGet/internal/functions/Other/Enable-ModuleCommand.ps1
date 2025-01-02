function Enable-ModuleCommand {
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
		Import-Module $ModuleName
		$module = Get-Module -Name $ModuleName

		$internal = [PSFramework.Utility.UtilityHost]::GetPrivateProperty('Internal', $module.SessionState)
		$mscope = [PSFramework.Utility.UtilityHost]::GetPrivateProperty('ModuleScope', $internal)
		[PSFramework.Utility.UtilityHost]::InvokePrivateMethod("RemoveAlias", $mscope, @($Name, $true))
	}
}