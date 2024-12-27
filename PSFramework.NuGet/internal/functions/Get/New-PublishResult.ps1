function New-PublishResult {
	<#
	.SYNOPSIS
		Creates a new publish result object, provided as result of Save-PSFModule.
	
	.DESCRIPTION
		Creates a new publish result object, provided as result of Save-PSFModule.
	
	.PARAMETER ComputerName
		The computer the module was deployed to.
	
	.PARAMETER Module
		The module that was deployed.
	
	.PARAMETER Version
		The version of the module that was deployed.
	
	.PARAMETER Success
		Whether the deployment action succeeded.
		Even if there is a message - which usually means something went wrong - success is possible.
		For example, when a cleanup step failed, but the intended action worked.
	
	.PARAMETER Message
		A message added to the result.
		Usually describes what went wrong - fully or partially.
		Some messages may be included with a success - when the actual goal was met, but something less important went wrong anyway.
	
	.PARAMETER Path
		The path deployed to.
		When deploying to a remote computer, this will include the local path from the perspective of the remote computer.
	
	.EXAMPLE
		PS C:\> New-PublishResult -ComputerName server1 -Module PSFramework -Version 1.12.346 -Success $true -Path 'C:\Program Files\WindowsPowerShell\Modules'

		Creates a report of how PSFramework in version 1.12.346 was successfully deployed to the default modules folder on server1
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding()]
	param (
		[string]
		$ComputerName,

		[string]
		$Module,

		[string]
		$Version,

		[bool]
		$Success,

		[string]
		$Message,

		[string]
		$Path
	)

	[PSCustomObject]@{
		PSTypeName   = 'PSFramework.NuGet.PublishResult'
		Computername = $ComputerName
		Module       = $Module
		Version      = $Version
		Success      = $Success
		Message      = $Message
		Path         = $Path
	}
}