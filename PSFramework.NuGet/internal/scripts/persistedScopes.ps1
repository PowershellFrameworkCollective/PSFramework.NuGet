foreach ($setting in Select-PSFConfig -FullName PSFramework.NuGet.ModuleScopes.* -Depth 3) {
	$regParam = @{
		Name = $setting._Name
		Path = $setting.Path
	}
	if ($setting.Description) { $regParam.Description = $setting.Description }
	Register-PSFModuleScope @regparam
}