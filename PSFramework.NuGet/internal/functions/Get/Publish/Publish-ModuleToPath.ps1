function Publish-ModuleToPath {
	[CmdletBinding()]
	param (
		$Module,

		[string]
		$Path,

		[switch]
		$ForceV3,

		$Cmdlet = $PSCmdlet
	)
	begin {
		$useV3 = $script:psget.V3 -or $ForceV3
		if (-not $useV3) {
			Assert-V2Publishing -Cmdlet $Cmdlet
		}
	}
	process {
		#TODO: Implement
		throw "Not Implemented Yet"


	}
}