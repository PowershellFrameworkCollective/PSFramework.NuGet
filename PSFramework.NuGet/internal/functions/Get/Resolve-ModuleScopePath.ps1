function Resolve-ModuleScopePath {
	[CmdletBinding()]
	param (
		[AllowEmptyString()]
		[string]
		$Scope,

		[AllowNull()]
		$ManagedSession,

		[ValidateSet('All', 'Any', 'None')]
		[string]
		$TargetHandling = 'None',

		$Cmdlet
	)
	begin {
		#region Code
		$code = {
			param ($Data)

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
		#endregion Code

		if (-not $Scope) {
			$Scope = 'AllUsers'
			if (-not $ManagedSession) { $Scope = 'CurrentUser' }
		}
	}
	process {
		throw "Not Implemented Yet!"

		


	}
}