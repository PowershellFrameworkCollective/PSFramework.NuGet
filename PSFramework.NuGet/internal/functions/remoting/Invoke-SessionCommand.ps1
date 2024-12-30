function Invoke-SessionCommand {
	<#
	.SYNOPSIS
		Executes a command in an already provided session and returns the results in a consistent manner.
	
	.DESCRIPTION
		Executes a command in an already provided session and returns the results in a consistent manner.
		This simplifies error handling, especially ErrorAction for errors that happen remotely.
		This command will never throw an error - it will always only return an object with three properties:

		+ Success (bool): Whether the operation succeeded.
		+ Error (ErrorRecord): If it failed, the error record. Will be deserialized, if it was not a remoting error.
		+ Data (object): Any return values the scriptblock generated.
	
	.PARAMETER Session
		The session to invoke the command in.
	
	.PARAMETER Code
		The Code to execute
	
	.PARAMETER ArgumentList
		The arguments to pass to the code
	
	.EXAMPLE
		PS C:\> Invoke-SessionCommand -Session $session -Code { Remove-Item -Path C:\Temp\* -Force -Recurse -ErrorAction stop }
		
		Tries to delete all items under C:\Temp in the remote session.
		Successful or not, it will always return a return object, reporting the details.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[System.Management.Automation.Runspaces.PSSession]
		$Session,

		[Parameter(Mandatory = $true)]
		[scriptblock]
		$Code,

		[object[]]
		$ArgumentList
	)
	process {
		$data = @{
			Code         = $Code
			ArgumentList = $ArgumentList
		}

		$scriptblock = {
			param ($Data)
			try {
				# Local Execution, but with Invoke-Command so that the arguments properly enumerate
				$result = Invoke-Command ([scriptblock]::Create($Data.Code.ToString())) -ArgumentList $Data.ArgumentList
				[PSCustomObject]@{
					Success = $true
					Error   = $null
					Data    = $result
				}
			}
			catch {
				[PSCustomObject]@{
					Success = $false
					Error   = $_
					Data    = $null
				}
			}
		}
		try { Invoke-Command -Session $Session -ScriptBlock $scriptblock -ArgumentList $data -ErrorAction Stop }
		catch {
			[PSCustomObject]@{
				Success = $false
				Error   = $_
				Data    = $null
			}
		}
	}
}