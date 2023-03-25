function Install-PSFPowerShellGet
{
	[CmdletBinding()]
	Param (
		[ValidateSet('V2Binaries', 'V2Latest', 'V3Latest')]
		[string]
		$Type = 'V2Binaries',

		[Parameter(ValueFromPipeline = $true)]
		[PSFComputer[]]
		$ComputerName = $env:COMPUTERNAME,

		[PSCredential]
		$Credential
	)
	
	begin
	{
		
	}
	process
	{
	
	}
	end
	{
	
	}
}
