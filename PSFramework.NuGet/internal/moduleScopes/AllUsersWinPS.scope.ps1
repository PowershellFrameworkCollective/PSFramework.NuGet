$code = {
	if ($PSVersionTable.PSVersion.Major -le 5) {
		return "$([Environment]::GetFolderPath("ProgramFiles"))\WindowsPowerShell\Modules"
	}
	if ($IsWindows) {
		return "$([Environment]::GetFolderPath("ProgramFiles"))\WindowsPowerShell\Modules"
	}
	'/usr/local/share/powershell/Modules'
}
$scopeParam = @{
	Name = 'AllUsersWinPS'
	ScriptBlock = $code
	Description = 'Default PS 5.1 path for modules visible to all users. Modules will be available to all versions of PowerShell. Will still work on non-Windows systems, but be no different to "AllUsers".'
}
Register-PSFModuleScope @scopeParam