$code = {
	if ($PSVersionTable.PSVersion.Major -le 5) {
		return "$([Environment]::GetFolderPath("MyDocuments"))\WindowsPowerShell\Modules"
	}
	if ($IsWindows) {
		return "$([Environment]::GetFolderPath("MyDocuments"))\PowerShell\Modules"
	}
	'~/.local/share/powershell/Modules'
}
$scopeParam = @{
	Name = 'CurrentUser'
	ScriptBlock = $code
	Description = 'Default path for modules visible to the current user only.'
}
Register-PSFModuleScope @scopeParam