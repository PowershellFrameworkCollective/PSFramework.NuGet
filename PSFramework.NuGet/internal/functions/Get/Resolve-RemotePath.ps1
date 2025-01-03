function Resolve-RemotePath {
	<#
	.SYNOPSIS
		Test for target paths on remote computers.
	
	.DESCRIPTION
		Test for target paths on remote computers.

		Has differentiated error handling (see description on TargetHandling or examples),
		in order to ensure proper tracking of all parallely processed targets.
	
	.PARAMETER Path
		The paths to check.
	
	.PARAMETER ComputerName
		The computers to check the paths on.
		Supports established PSSession objects.

	.PARAMETER ManagedSession
		Managed Remoting Sessions to associate with the paths resolved.
		Used later to bulk-process the paths in parallel.
	
	.PARAMETER PathHandling
		Whether all specified paths must exist on a target computer, or whether a single finding counts as success.
		Defaults to: All
	
	.PARAMETER TargetHandling
		How the command should handle unsuccessful computer targets:
		All unsuccessful checks lead to a non-terminating exception.
		However, depending on this parameter, a forced terminating exception might be thrown:
		- "All": Even a single unsuccessful computer leads to terminal errors.
		- "Any": If no target was successful, terminate
		- "None": Never terminate
		Defaults to: None
	
	.PARAMETER Cmdlet
		The $PSCmdlet variable of the caller.
		As this is an internal utility command, this allows it to terminate in the context of the calling command and remain invisible to the user.
	
	.EXAMPLE
		PS C:\> Resolve-RemotePath -Path C:\Temp -ComputerName $computers

		Checks for C:\Temp on all computers in $computers
		Will not generate any terminating errors.

	.EXAMPLE
		PS C:\> Resolve-RemotePath -Path C:\Temp -ComputerName $computers -TargetHandling All

		Checks for C:\Temp on all computers in $computers
		If even a single computer cannot be reached or does not have the path, this will terminate the command.

	.EXAMPLE
		PS C:\> Resolve-RemotePath -Path C:\Temp, C:\Tmp -ComputerName $computers -TargetHandling All -PathHandling Any

		Checks for C:\Temp or C:\Tmp on all computers in $computers
		Each computer is considered successful, if one of the two paths exist on it.
		If even a single computer is not successful - has neither path or cannot be reached - this command will terminate.

	.EXAMPLE
		PS C:\> Resolve-RemotePath -Path C:\Temp, C:\Tmp -ComputerName $computers -TargetHandling Any -PathHandling Any -ErrorAction SilentlyContinue

		Checks for C:\Temp or C:\Tmp on all computers in $computers
		Each computer is considered successful, if one of the two paths exist on it.
		This command will continue unbothered, so long as at least one computer is successful.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "")]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string[]]
		$Path,

		[AllowEmptyCollection()]
		[AllowNull()]
		[PSFComputer[]]
		$ComputerName,

		$ManagedSession,

		[ValidateSet('All', 'Any')]
		[string]
		$PathHandling = 'All',

		[ValidateSet('All', 'Any', 'None')]
		[string]
		$TargetHandling = 'None',

		$Cmdlet = $PSCmdlet
	)
	begin {
		#region Implementing Code
		$code = {
			param ($Data)

			$pathResults = foreach ($path in $Data.Path) {
				try {
					$resolvedPaths = Resolve-Path -Path $path -ErrorAction Stop
				}
				catch {
					[PSCustomObject]@{
						ComputerName = $env:COMPUTERNAME
						Path         = $path
						Exists       = $false
					}
					continue
				}
				foreach ($resolvedPath in $resolvedPaths) {
					[PSCustomObject]@{
						ComputerName = $env:COMPUTERNAME
						Path         = $resolvedPath
						Exists       = $true
					}
				}
			}

			$result = [PSCustomObject]@{
				ComputerName = $env:COMPUTERNAME
				Path         = $Data.Path
				Results      = $pathResults
				ExistsAll    = @($pathResults).Where{ -not $_.Exists }.Count -lt 1
				ExistsAny    = @($pathResults).Where{ $_.Exists }.Count -gt 0
				Success      = $null
				Error        = $null
				SessionID    = $global:__PsfSessionId
				Session      = $null
			}
			if ($Data.PathHandling -eq 'All') { $result.Success = $result.ExistsAll }
			else { $result.Success = $result.ExistsAny }

			if (-not $result.Success) {
				$message = "[$env:COMPUTERNAME] Path not found: $(@($pathResults).Where{ -not $_.Exists }.ForEach{ "'$($_.Path)'" } -join ', ')"
				$result.Error = [System.Management.Automation.ErrorRecord]::new(
					[System.Exception]::new($message),
					'PathNotFound',
					[System.Management.Automation.ErrorCategory]::ObjectNotFound,
					@(@($pathResults).Where{ -not $_.Exists }.ForEach{ "'$($_.Path)'" })
				)
			}

			$result
		}
		#endregion Implementing Code

		# Passing a single array-argument as a hashtable is more reliable
		$data = @{ Path = $Path; PathHandling = $PathHandling }
	}
	process {
		#region Collect Test-Results
		if (-not $ComputerName) {
			$testResult = & $code $data
		}
		else {
			$failed = $null
			$testResult = Invoke-PSFCommand -ComputerName $ComputerName -ScriptBlock $code -ArgumentList $data -ErrorAction SilentlyContinue -ErrorVariable failed
			$failedResults = foreach ($failedTarget in $failed) {
				[PSCustomObject]@{
					ComputerName = $failedTarget.TargetObject
					Path         = $Path
					Results      = @()
					ExistsAll    = $null
					ExistsAny    = $null
					Success      = $false
					Error        = $failedTarget
					SessionID    = $null
					Session      = $null
				}
			}
			$testResult = @($testResult) + @($failedResults) | Remove-PSFNull
		}
		#endregion Collect Test-Results

		foreach ($result in $testResult) {
			if ($result.SessionID) { $result.Session = @($ManagedSession).Where{ $_.ID -eq $result.SessionID }[0] }
			[PSFramework.Object.ObjectHost]::AddScriptMethod($result, 'ToString', { '{0}: {1}' -f $this.ComputerName, ($this.Path -join ' | ') })
			if ($result.Success) { continue }

			if (-not $result.Results) {
				Write-PSFMessage -String 'Resolve-RemotePath.Error.UnReached' -StringValues $result.ComputerName, ($Path -join ' | ') -Tag fail, connect -Target $result
			}
			else {
				Write-PSFMessage -String 'Resolve-RemotePath.Error.NotFound' -StringValues $result.ComputerName, (@($result.Results).Where{ -not $_.Exists }.Path -join ' | ') -Tag fail, notfound -Target $result
			}

			$Cmdlet.WriteError($result.Error)
		}

		if ($TargetHandling -eq 'All' -and @($testResult).Where{ -not $_.Success }.Count -gt 0) {
			Stop-PSFFunction -String 'Resolve-RemotePath.Fail.NotAll' -StringValues (@($testResult).Where{-not $_.Success }.ComputerName -join ' | '), ($Path -join ' | ') -EnableException $true -Cmdlet $Cmdlet
		}
		if ($TargetHandling -eq 'Any' -and @($testResult).Where{ $_.Success }.Count -eq 0) {
			Stop-PSFFunction -String 'Resolve-RemotePath.Fail.NotAny' -StringValues ($testResult.ComputerName -join ' | '), ($Path -join ' | ') -EnableException $true -Cmdlet $Cmdlet
		}

		$testResult
	}
}