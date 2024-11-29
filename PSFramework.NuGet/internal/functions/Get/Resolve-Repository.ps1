function Resolve-Repository {
	<#
	.SYNOPSIS
		Resolves the PowerShell Repository to use, including their order.
	
	.DESCRIPTION
		Resolves the PowerShell Repository to use, including their order.
		This differs from Get-PSFRepository by throwing a terminating exception in case no repository was found.
	
	.PARAMETER Name
		Names of the Repositories to lookup.
		Can be multiple, can use wildcards.
	
	.PARAMETER Type
		Whether to return PSGet V2, V3 or all repositories.
		Defaults to: "All"
	
	.PARAMETER Cmdlet
		The $PSCmdlet variable of the caller.
		As this is an internal utility command, this allows it to terminate in the context of the calling command and remain invisible to the user.
	
	.EXAMPLE
		PS C:\> Resolve-Repository -Name PSGallery, Contoso -Cmdlet $PSCmdlet

		Returns all repositories instances named PSGallery or Contoso, whether registered in V2 or V3

	.EXAMPLE
		Ps C:\> Resolve-Repository -Name PSGallery -Type V3 -Cmdlet $PSCmdlet

		Returns the PSGet V3 instance of the PSGallery repository.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string[]]
		$Name,

		[ValidateSet('All', 'V2', 'V3')]
		[string]
		$Type = 'All',

		$Cmdlet = $PSCmdlet
	)
	process {
		$repos = Get-PSFRepository -Name $Name -Type $Type

		if (-not $repos) {
			Stop-PSFFunction -String 'Resolve-Repository.Error.NoRepo' -StringValues ($Name -join ', '), $Type -EnableException $true -Cmdlet $Cmdlet -Category ObjectNotFound
		}
		$repos
	}
}