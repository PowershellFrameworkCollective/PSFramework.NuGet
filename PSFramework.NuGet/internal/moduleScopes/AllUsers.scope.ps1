$code = {
	if ($PSVersionTable.PSVersion.Major -le 5) {
		return "$([Environment]::GetFolderPath("ProgramFiles"))\WindowsPowerShell\Modules"
	}
	if ($IsWindows) {
		$path = "$([Environment]::GetFolderPath("ProgramFiles"))\PowerShell\Modules"
		if (-not (Test-Path -Path $path)) {
			$null = New-Item -Path $path -ItemType Directory -Force -ErrorAction Ignore
		}
		return $path
	}
	'/usr/local/share/powershell/Modules'
}
$scopeParam = @{
	Name = 'AllUsers'
	ScriptBlock = $code
	Description = 'Default path for modules visible to all users.'
}
Register-PSFModuleScope @scopeParam