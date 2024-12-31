function Copy-Module {
	[CmdletBinding()]
	param (
		[string]
		$Path,

		[string]
		$Destination,

		$Cmdlet = $PSCmdlet,

		[switch]
		$Continue,

		[string]
		$ContinueLabel
	)
	begin {
		$killIt = $ErrorActionPreference -eq 'Stop'
		$stopCommon = @{
			Cmdlet          = $Cmdlet
			EnableException = $killIt
		}
		if ($Continue) { $stopCommon.Continue = $true }
		if ($ContinueLabel) { $stopCommon.ContinueLabel = $ContinueLabel }
	}
	process {
		$sourceDirectoryPath = $Path
		if ($Path -like '*.psd1') { $sourceDirectoryPath = Split-Path -Path $Path }

		$moduleName = Split-Path -Path $sourceDirectoryPath -Leaf
		if ($moduleName -match '^\d+(\.\d+){1,3}$') {
			$moduleName = Split-Path -Path (Split-Path -Path $sourceDirectoryPath) -Leaf
		}

		#region Validation
		$manifestPath = Join-Path -Path $sourceDirectoryPath -ChildPath "$moduleName.psd1"
		if (-not (Test-Path -Path $manifestPath)) {
			Stop-PSFFunction -String 'Copy-Module.Error.ManifestNotFound' -StringValues $Path -Target $Path @stopCommon -Category ObjectNotFound
			return
		}

		$tokens = $null
		$errors = $null
		$ast = [System.Management.Automation.Language.Parser]::ParseFile($manifestPath, [ref]$tokens, [ref]$errors)

		if ($errors) {
			Stop-PSFFunction -String 'Copy-Module.Error.ManifestSyntaxError' -StringValues $Path -Target $Path @stopCommon -Category ObjectNotFound
			return
		}
		#endregion Validation

		#region Deploy to Staging
		try { $null = New-Item -Path $Destination -Name $moduleName -ItemType Directory -ErrorAction Stop }
		catch {
			Stop-PSFFunction -String 'Copy-Module.Error.StagingFolderFailed' -StringValues $Path -Target $Path @stopCommon -ErrorRecord $_
			return
		}

		$destinationPath = Join-Path -Path $Destination -ChildPath $moduleName
		try { Copy-Item -Path "$($sourceDirectoryPath.Trim('\/'))\*" Destination $destinationPath -Recurse -Force -ErrorAction Stop }
		catch {
			Stop-PSFFunction -String 'Copy-Module.Error.StagingFolderCopy' -StringValues $Path -Target $Path @stopCommon -ErrorRecord $_
			return
		}
		#endregion Deploy to Staging

		$hashtableAst = $ast.EndBlock.Statements[0].PipelineElements[0].Expression
		[PSCustomObject]@{
			Name            = $moduleNamee
			Path            = $destinationPath
			SourcePath      = $sourceDirectoryPath
			Author          = @($hashtableAst.KeyValuePairs).Where{ $_.Item1.Value -eq 'Author' }.Item2.PipelineElements.Expression.Value
			Version         = @($hashtableAst.KeyValuePairs).Where{ $_.Item1.Value -eq 'ModuleVersion' }.Item2.PipelineElements.Expression.Value
			Description     = @($hashtableAst.KeyValuePairs).Where{ $_.Item1.Value -eq 'Description' }.Item2.PipelineElements.Expression.Value
			RequiredModules = Read-ManifestDependency -Path $manifestPath
		}
	}
}