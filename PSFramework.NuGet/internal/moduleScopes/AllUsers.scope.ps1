$code = {
	if ($PSVersionTable.PSVersion.Major -le 5) {
		return "$([Environment]::GetFolderPath("ProgramFiles"))\WindowsPowerShell\Modules"
	}
	if ($IsWindows) {
		return "$([Environment]::GetFolderPath("ProgramFiles"))\PowerShell\Modules"
	}
	'/usr/local/share/powershell/Modules'
}
$scopeParam = @{
	Name = 'AllUsers'
	ScriptBlock = $code
	Description = 'Default path for modules visible to all users.'
}
Register-PSFModuleScope @scopeParam