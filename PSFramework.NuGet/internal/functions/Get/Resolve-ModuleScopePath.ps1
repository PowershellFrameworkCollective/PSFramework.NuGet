function Resolve-ModuleScopePath {
	<#
	.SYNOPSIS
		Resolves the paths associated with the selected scope.
	
	.DESCRIPTION
		Resolves the paths associated with the selected scope.
		Returns separate results per computer, to account for differentiated, dynamic scope-path resolution.

	.PARAMETER Scope
		The scope to resolve the paths for.
		Defaults to "CurrentUser" on local deployments.
		Defaults to "AllUsers" on remote deployments.
	
	.PARAMETER ManagedSession
		Managed remoting sessions (if any).
		Use New-ManagedSession to establish these.
	
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
		PS C:\> Resolve-ModuleScopePath -Scope AllUsers -ManagedSession $managedSessions -TargetHandling Any -PathHandling Any -Cmdlet $PSCmdlet

		Resolves the path to use for the "AllUsers" scope for each computer in $managedSessions - or the local computer if none.
		If the scope resolves to multiple paths, any single existing one will consider the respective computer as successul.
		If any computer at all resolved successfully, the command will return and allow the caller to continue.
		Otherwise it will end the calling command with a terminating exception.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "")]
	[CmdletBinding()]
	param (
		[AllowEmptyString()]
		[string]
		$Scope,

		[AllowNull()]
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
		#region Code
		$code = {
			param (
				$Data,
				$PathHandling
			)

			$result = [PSCustomObject]@{
				ComputerName = $env:COMPUTERNAME
				Scope        = $Data.Name
				Path         = $Data.Path
				Results      = @()
				ExistsAll    = $false
				ExistsAny    = $false
				Success      = $false
				Error        = $null
				SessionID    = $global:__PsfSessionId
				Session      = $null
			}

			#region Calculate Target paths
			$targetPaths = $Data.Path
			if ($Data.ScriptBlock) {
				$pathCalculator = [ScriptBlock]::Create($Data.ScriptBlock.ToString())
				if (Get-Module PSFramework) {
					try { $targetPaths = ([PsfScriptBlock]$pathCalculator).InvokeGlobal() }
					catch {
						$result.Error = $_
						return $result
					}
				}
				else {
					try {
						$targetPaths = & $pathCalculator
					}
					catch {
						$result.Error = $_
						return $result
					}
				}
			}
			#endregion Calculate Target paths

			$pathResults = foreach ($path in $targetPaths) {
				if (-not $path) { continue }
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

			$result.Results = $pathResults
			$result.ExistsAll = @($pathResults).Where{ -not $_.Exists }.Count -lt 1
			$result.ExistsAny = @($pathResults).Where{ $_.Exists }.Count -gt 0

			if ($PathHandling -eq 'All') { $result.Success = $result.ExistsAll }
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
		#endregion Code

		$killIt = $ErrorActionPreference -eq 'Stop'
		if (-not $Scope) {
			$Scope = 'AllUsers'
			if (-not $ManagedSession) { $Scope = 'CurrentUser' }
		}
		$scopeObject = $script:moduleScopes[$Scope]
		if (-not $scopeObject) {
			Stop-PSFFunction -String 'Resolve-ModuleScopePath.Error.ScopeNotFound' -StringValues $Scope, ((Get-PSFModuleScope).Name -join ', ') -Cmdlet $Cmdlet -EnableException $killIt
			return
		}
	}
	process {
		if (Test-PSFFunctionInterrupt) { return }

		#region Collect Test-Results
		if (-not $ManagedSession) {
			$testResult = & $code $scopeObject, $PathHandling
		}
		else {
			$failed = $null
			$testResult = Invoke-PSFCommand -ComputerName $ManagedSession.Session -ScriptBlock $code -ArgumentList $scopeObject, $PathHandling -ErrorAction SilentlyContinue -ErrorVariable failed
			$failedResults = foreach ($failedTarget in $failed) {
				[PSCustomObject]@{
					ComputerName = $failedTarget.TargetObject
					Scope        = $scopeObject.Name
					Path         = $scopeObject.Path
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

		#region Evaluate Success
		foreach ($result in $testResult) {
			if ($result.SessionID) { $result.Session = @($ManagedSession).Where{ $_.ID -eq $result.SessionID }[0] }
			[PSFramework.Object.ObjectHost]::AddScriptMethod($result, 'ToString', { '{0}: {1}' -f $this.ComputerName, ($this.Path -join ' | ') })
			if ($result.Success) { continue }

			if (-not $result.Results) {
				Write-PSFMessage -String 'Resolve-ModuleScopePath.Error.UnReached' -StringValues $result.ComputerName, ($result.Path -join ' | ') -Tag fail, connect -Target $result
			}
			else {
				Write-PSFMessage -String 'Resolve-ModuleScopePath.Error.NotFound' -StringValues $result.ComputerName, (@($result.Results).Where{ -not $_.Exists }.Path -join ' | ') -Tag fail, notfound -Target $result
			}

			$Cmdlet.WriteError($result.Error)
		}

		if ($TargetHandling -eq 'All' -and @($testResult).Where{ -not $_.Success }.Count -gt 0) {
			Stop-PSFFunction -String 'Resolve-ModuleScopePath.Fail.NotAll' -StringValues (@($testResult).Where{-not $_.Success }.ComputerName -join ' | ') -EnableException $true -Cmdlet $Cmdlet
		}
		if ($TargetHandling -eq 'Any' -and @($testResult).Where{ $_.Success }.Count -eq 0) {
			Stop-PSFFunction -String 'Resolve-ModuleScopePath.Fail.NotAny' -StringValues ($testResult.ComputerName -join ' | ') -EnableException $true -Cmdlet $Cmdlet
		}
		#endregion Evaluate Success

		$testResult
	}
}