function Resolve-ModuleScopePath {
	[CmdletBinding()]
	param (
		[string]
		$Scope,

		$ManagedSession,

		[ValidateSet('All', 'Any', 'None')]
		[string]
		$TargetHandling = 'None',

		$Cmdlet
	)
	process {
		throw "Not Implemented Yet!"
	}
}