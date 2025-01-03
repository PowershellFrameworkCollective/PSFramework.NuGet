function Publish-ModuleV3 {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		$Module,

		$Repository,

		[string]
		$ApiKey,

		[PSCredential]
		$Credential,

		[switch]
		$SkipDependenciesCheck,

		[switch]
		$Continue,

		[string]
		$ContinueLabel,

		$Cmdlet = $PSCmdlet
	)
	process {
		$killIt = $ErrorActionPreference -eq 'Stop'

		# Ensure to now overwrite a local file
		if ($Repository.Uri -like 'file:*') {
			$targetPath = $Repository.Uri -replace '^file:///' -replace 'file:'
			$targetFile = Join-Path -Path $targetPath -ChildPath "$($Module.Name).$($Module.Version).nupkg"
			if (Test-Path -path $targetFile) {
				Stop-PSFFunction -String 'Publish-ModuleV3.Error.AlreadyPublished' -StringValues $Module.Name, $Module.Version, $Repository.Name -Cmdlet $Cmdlet -EnableException $killIt -Continue:$Continue -ContinueLabel $ContinueLabel -Target "$($Module.Name) ($($Module.Version))"
				return
			}
		}

		$commonPublish = @{
			Repository = $Repository.Name
			Confirm = $false
		}
		if ($Repository.Credential) { $commonPublish.Credential = $Credential }
		if ($Credential) { $commonPublish.Credential = $Credential }
		if ($ApiKey) { $commonPublish.ApiKey = $ApiKey }
		if ($SkipDependenciesCheck) {
			$commonPublish.SkipDependenciesCheck = $SkipDependenciesCheck
			# Parity with V2 - Disabling the dependency check will also prevent Manifest Validation there
			$commonPublish.SkipModuleManifestValidate = $true
		}

		Invoke-PSFProtectedCommand -ActionString 'Publish-ModuleV3.Publish' -ActionStringValues $Module.Name, $Module.Version, $Repository -ScriptBlock {
			Publish-PSResource @commonPublish -Path $Module.Path -ErrorAction Stop
		} -Target "$($Module.Name) ($($Module.Version))" -PSCmdlet $Cmdlet -EnableException $killIt -Continue:$Continue -ContinueLabel $ContinueLabel
	}
}