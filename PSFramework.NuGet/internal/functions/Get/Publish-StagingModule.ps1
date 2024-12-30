function Publish-StagingModule {
	<#
	.SYNOPSIS
		Dispatches module publishing commands.
	
	.DESCRIPTION
		Dispatches module publishing commands.
		This command takes the path to where the locally cached modules are held before copying them to their target location, then ensures they are sent there.
		It differentiates between local deployments and remote deployments, all remote deployments being performed in parallel.
	
	.PARAMETER Path
		The path to where the modules lie that need to be deployed.
	
	.PARAMETER TargetPath
		The targeting information that determines where the modules get published.
		Contrary to the name, this is not a string but expects the output from Resolve-RemotePath.
		The object includes the paths (plural) and the session information needed for remote deployments.
	
	.PARAMETER ThrottleLimit
		Up to how many computers to deploy the modules to in parallel.
		Defaults to: 5
		Default can be configured under the 'PSFramework.NuGet.Remoting.Throttling' setting.
	
	.PARAMETER Force
		Redeploy a module that already exists in the target path.
		By default it will skip modules that do already exist in the target path.
	
	.PARAMETER Cmdlet
		The $PSCmdlet variable of the calling command, used to ensure errors happen within the scope of the caller, hiding this internal helper command from the user.
	
	.EXAMPLE
		PS C:\> Publish-StagingModule -Path $stagingDirectory -TargetPath $targets -Force:$Force -Cmdlet $PSCmdlet

		Deploys all modules under $stagingDirectory to the target paths/computers in $targets.
		Will overwrite existing modules if $Force is $true.
	#>
	[CmdletBinding()]
	param (
		[string]
		$Path,

		$TargetPath,

		[ValidateRange(1, [int]::MaxValue)]
		[int]
		$ThrottleLimit = (Get-PSFConfigValue -FullName 'PSFramework.NuGet.Remoting.Throttling'),

		[switch]
		$Force,

		$Cmdlet
	)
	
	process {
		$localPaths = @($TargetPath).Where{ -not $_.Session }[0]
		$remotePaths = @($TargetPath).Where{ $_.Session }

		if ($localPaths) {
			Publish-StagingModuleLocal -Path $Path -TargetPath $localPaths -Force:$Force -Cmdlet $Cmdlet
		}
		if ($remotePaths) {
			Publish-StagingModuleRemote -Path $Path -TargetPath $remotePaths -ThrottleLimit $ThrottleLimit -Force:$Force
		}
	}
}