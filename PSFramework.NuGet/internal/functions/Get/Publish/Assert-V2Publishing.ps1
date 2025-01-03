function Assert-V2Publishing {
	<#
	.SYNOPSIS
		Ensures users are warned when trying to publish using GetV2 on a system possibly not configured as such.
	
	.DESCRIPTION
		Ensures users are warned when trying to publish using GetV2 on a system possibly not configured as such.
		Warning only shown once per session.
	
	.PARAMETER Cmdlet
		The PSCmdlet variable of the calling command, used to ensure errors happen within the scope of the caller, hiding this internal helper command from the user.
	
	.EXAMPLE
		ps C:\> Assert-V2Publishing -Cmdlet $PSCmdlet
		
		Ensures users are warned when trying to publish using GetV2 on a system possibly not configured as such.
	#>
	[CmdletBinding()]
	param (
		$Cmdlet = $PSCmdlet
	)
	process {
		if ($script:psget.v2CanPublish) { return }
		Write-PSFMessage -Level Warning -String 'Assert-V2Publishing.CannotPublish' -PSCmdlet $Cmdlet -Once GetV2Publish
	}
}