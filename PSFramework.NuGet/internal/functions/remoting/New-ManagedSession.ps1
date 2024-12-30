function New-ManagedSession {
	<#
	.SYNOPSIS
		Creates new remoting sessions where needed and flags them all with an ID that is shared, both locally and remotely.
	
	.DESCRIPTION
		Creates new remoting sessions where needed and flags them all with an ID that is shared, both locally and remotely.
		This allows easily mapping arguments when parallel invocation makes argument separation difficult.

		Note: While a nifty feature in general, this has been superseded in Save-PSFModule, what it originally was developed for.
		The command still provides useful convenience of standardizing input when provided mixed input types,
		as sessions outside of the PSFramework management are needed for now, but its original intent is no longer critical.
	
	.PARAMETER ComputerName
		The computers to deploy the modules to.
		Accepts both names or established PSRemoting sessions.
	
	.PARAMETER Credential
		Credentials to use for remoting connections (if present).
	
	.PARAMETER ConfigurationName
		The name of the PSSessionConfiguration to use for the remoting connection.
		Changing this allows you to execute remote code in PowerShell 7 if configured on the other side.
		This setting can be updated via configuration, using the 'PSFramework.NuGet.Remoting.DefaultConfiguration' setting.
	
	.PARAMETER Type
		What kind of session to create.
		+ Temporary: Should be deleted after use.
		+ Persistent: Should be kept around.
		Computer targets that are already established PSSessions will be flagged as "External" instead.
	
	.PARAMETER Cmdlet
		The $PSCmdlet variable of the calling command, used to ensure errors happen within the scope of the caller, hiding this internal helper command from the user.
	
	.PARAMETER EnableException
		This parameters disables user-friendly warnings and enables the throwing of exceptions.
		This is less user friendly, but allows catching exceptions in calling scripts.
	
	.EXAMPLE
		PS C:\> New-ManagedSession -ComputerName $ComputerName -Credential $RemotingCredential -Cmdlet $PSCmdlet -Type Temporary
		
		Establishes sessions to all targets in $ComputerName if needed, using the credentials in $RemotingCredential (if any).
		The newly-established sessions will be considered temporary and should be purged before the task is done.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "")]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "")]
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

		$Cmdlet,

		[switch]
		$EnableException
	)
	begin {
		$param = @{ }
		if ($ConfigurationName -ne 'Microsoft.PowerShell') { $param.ConfigurationName = $ConfigurationName }
		if ($Credential) { $param.Credential = $Credential }

		$killIt = $EnableException -or $ErrorActionPreference -eq 'Stop'
	}
	process {
		if (-not $ComputerName) { return }

		#region Collect Sessions
		$sessionHash = @{ }
		@($ComputerName).Where{ $_.Type -eq 'PSSession' }.ForEach{
			if ($_.InputObject.State -ne 'Opened') {
				Stop-PSFFunction -String 'New-ManagedSession.Error.BrokenSession' -StringValues "$_" -FunctionName 'New-ManagedSession' -ModuleName 'PSFramework.NuGet' -Cmdlet $Cmdlet -EnableException $killIt
				return
			}
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
				Write-PSFMessage -Level Warning -String 'New-ManagedSession.Error.Connect' -StringValues $fail.TargetObject -ErrorRecord $fail -Target $fail.TargetObject -PSCmdlet $Cmdlet -EnableException $killIt
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

		if ($sessionHash.Count -eq 0) { return }

		#region Identify Sessions
		$identifiers = Invoke-Command -Session $sessionHash.Values.Session -ScriptBlock {
			if (-not $global:__PsfSessionId) { $global:__PsfSessionId = "$([Guid]::NewGuid())" }

			[PSCustomObject]@{
				ID = $global:__PsfSessionId
			}
		}
		@($identifiers).ForEach{ $sessionHash["$($_.RunspaceId)"].ID = $_.ID }
		#endregion Identify Sessions

		$sessionHash.Values
	}
}