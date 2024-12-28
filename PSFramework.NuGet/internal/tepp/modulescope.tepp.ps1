Register-PSFTeppScriptblock -Name 'PSFramework.NuGet.ModuleScope' -ScriptBlock {
	foreach ($scope in Get-PSFModuleScope) {
		@{ Text = $scope.Name; ToolTip = $scope.Description }
	}
} -Global