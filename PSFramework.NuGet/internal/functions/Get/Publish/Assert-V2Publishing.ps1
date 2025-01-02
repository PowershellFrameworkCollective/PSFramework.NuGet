function Assert-V2Publishing {
	[CmdletBinding()]
	param (
		$Cmdlet = $PSCmdlet
	)
	process {
		if ($script:psget.v2CanPublish) { return }
		Write-PSFMessage -Level Warning -String 'Assert-V2Publishing.CannotPublish' -PSCmdlet $Cmdlet -Once GetV2Publish
	}
}