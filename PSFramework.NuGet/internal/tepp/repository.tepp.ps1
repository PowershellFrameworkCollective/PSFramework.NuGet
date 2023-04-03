<#
# Example:
Register-PSFTeppScriptblock -Name "PSFramework.NuGet.alcohol" -ScriptBlock { 'Beer','Mead','Whiskey','Wine','Vodka','Rum (3y)', 'Rum (5y)', 'Rum (7y)' }
#>

Register-PSFTeppScriptblock -Name "PSFramework.NuGet.Repository" -ScriptBlock {
	foreach ($repository in Get-PSFRepository | Group-Object Name) {
		@{
			Text = $repository.Name
			Tooltip = '[{0}] {1}' -f (($repository.Group.Type | Sort-Object) -join ', '), $repository.Name
		}
	}
}