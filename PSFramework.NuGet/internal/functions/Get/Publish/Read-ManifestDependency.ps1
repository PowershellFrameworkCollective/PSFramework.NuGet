function Read-ManifestDependency {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Path
	)
	process {
		$tokens = $null
		$errors = $null
		$ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)

		$requirements = foreach ($requirement in @($ast.EndBlock.Statements[0].PipelineElements[0].Expression.KeyValuePairs).Where{ $_.Item1.Value -eq 'RequiredModules' }.Item2.PipelineElements.Expression.SubExpression.Statements) {
			$actualRequirement = $requirement.PipelineElements[0].Expression
			switch ($actualRequirement.GetType().Name) {
				'HashtableAst' {
					[PSCustomObject]@{
						Name    = $actualRequirement.KeyValuePairs.Where{ $_.Item1.Value -eq 'ModuleName' }.Item2.PipelineElements.Expression.Value
						Version = $actualRequirement.KeyValuePairs.Where{ $_.Item1.Value -match 'Version$' }.Item2.PipelineElements.Expression.Value -as [version]
						Exact   = $actualRequirement.KeyValuePairs.Item1.Value -contains 'RequiredVersion'
					}
				}
				'StringConstantExpressionAst' {
					[PSCustomObject]@{
						Name    = $actualRequirement.Value
						Version = '0.0.0' -as [version]
						Exact   = $false
					}
				}
				default {
					throw "Unexpected Module Dependency AST in $Path : $($actualRequirement.GetType().Name)"
				}
			}
		}
		foreach ($requirement in $requirements) {
			if ($requirement.Exact -and -not $requirement.Version) {
				Write-PSFMessage -Level Warning -String 'Read-ManifestDependency.Warning.VersionError' -StringValues $Path, $requirement.Name
			}
			if (-not $requirement.Version) {
				$requirement.Version = '0.0.0' -as [version]
			}

			$requirement
		}
	}
}