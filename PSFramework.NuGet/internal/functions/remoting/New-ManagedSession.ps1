function New-ManagedSession {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[AllowEmptyCollection()]
		[AllowNull()]
		[PSFComputer[]]
		$ComputerName,

		[PSCredential]
		$Credential,

		[string]
		$ConfigurationName = (Get-PSFConfigValue -FullName 'PSFramework.NuGet.Remoting.DefaultConfiguration'),

		[Parameter(Mandatory = $true)]
		[ValidateSet('Persistent', 'Temporary')]
		[string]
		$Type,

		[switch]
		$EnableException
	)
	begin {
		$param = @{ ConfigurationName = $ConfigurationName }
		if ($Credential) { $param.Credential = $Credential }

		$killIt = $EnableException -or $ErrorActionPreference -eq 'Stop'
	}
	process {
		if (-not $ComputerName) { return }

		#region Collect Sessions
		$sessionHash = @{ }
		@($ComputerName).Where{ $_.Type -eq 'PSSession' }.ForEach{
			$sessionHash["$($_.InputObject.InstanceId)"] = [PSCustomObject]@{
				PSTypeName   = 'PSFramework.NuGet.ManagedSession'
				Type         = 'Extern'
				ComputerName = $_.InputObject.Computername
				Session      = $_.InputObject
				ID           = $null
			}
		}

		$nonSessions = @($ComputerName).Where{ $_.Type -ne 'PSSession' }
		if ($nonSessions) {
			$pssessions = New-PSSession -ComputerName $nonSessions @param -ErrorAction SilentlyContinue -ErrorVariable failedConnections
			foreach ($fail in $failedConnections) {
				Write-PSFMessage -Level Warning -String 'New-ManagedSession.Error.Connect' -StringValues $fail.TargetObject -ErrorRecord $fail -Target $fail.TargetObject -PSCmdlet $PSCmdlet -EnableException $killIt
			}

			@($pssessions).ForEach{
				$sessionHash["$($_.InstanceId)"] = [PSCustomObject]@{
					PSTypeName   = 'PSFramework.NuGet.ManagedSession'
					Type         = $Type
					ComputerName = $_.Computername
					Session      = $_
					ID           = $null
				}
			}
		}
		#endregion Collect Sessions

		#region Identify Sessions
		$identifiers = Invoke-Command -Session $sessionHash.Values.Session -ScriptBlock {
			$global:__PsfSessionId = "$([Guid]::NewGuid())"

			[PSCustomObject]@{
				ID = $global:__PsfSessionId
			}
		}
		@($identifiers).ForEach{ $sessionHash["$($_.RunspaceId)"].ID = $_.ID }
		#endregion Identify Sessions

		$sessionHash.Values
	}
}