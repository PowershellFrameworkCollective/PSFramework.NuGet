# This is where the strings go, that are written by
# Write-PSFMessage, Stop-PSFFunction or the PSFramework validation scriptblocks
@{
	'Assert-V2Publishing.CannotPublish'                          = 'PowerShellGet may not yet be configured for publishing modules. This may prompt you to install required binaries and fail to publish if denied or internet access is not available. If this indeed fails, you can configure it by running "Install-PSFPowerShellGet" from an elevated console (no internet access required).' # 

	'Copy-Module.Error.ManifestNotFound'                         = 'No module manifest found in {0}' # $Path
	'Copy-Module.Error.ManifestSyntaxError'                      = 'Invalid manifest, contains syntax errors: {0}' # $manifestPath
	'Copy-Module.Error.StagingFolderCopy'                        = 'Failed to deploy module to staging directory when trying to publish {0}' # $Path
	'Copy-Module.Error.StagingFolderFailed'                      = 'Failed to create staging folder when trying to publish {0}' # $Path

	'Install-PSFModule.Error.Installation'                       = 'Failed to install {0}' # $Name -join ','
	'Install-PSFModule.Error.NoComputerValid'                    = 'Unable to establish ANY remote connections to {0}' # $ComputerName -join ', 
	'Install-PSFModule.Error.Setup'                              = 'Failed to prepare to install {0}' # $Name -join ','

	'New-ManagedSession.Error.BrokenSession'                     = 'Received a session to {0} that is already in a broken state. Repair the conection and try again.' # "$_"
	'New-ManagedSession.Error.Connect'                           = 'Failed to connect to {0}' # $fail.TargetObject

	'Publish-ModuleToPath.Error.AlreadyPublished'                = 'The module {0} ({1}) has already been published to {2}. Do not forget to raise your module version before publishing.' # $Module.Name, $Module.Version, $Path
	'Publish-ModuleToPath.Error.FailedToStaging.V2'              = 'Failed to publish {0} ({1}) to a staging repository.' # $module.Name, $module.Version
	'Publish-ModuleToPath.Error.FailedToStaging.V3'              = 'Failed to publish {0} ({1}) to a staging repository.' # $module.Name, $module.Version
	'Publish-ModuleToPath.Publishing'                            = 'Publishing {0} ({1})' # $module.Name, $module.Version

	'Publish-ModuleV2.Publish'                                   = 'Publishing module {0} ({1}) to repository {2}' # $Module.Name, $Module.Version, $Repository.Name

	'Publish-ModuleV3.Error.AlreadyPublished'                    = 'Module {0} ({1}) has already been published to repository {2}. Do not forget to raise your module version before publishing.' # $Module.Name, $Module.Version, $Repository.Name
	'Publish-ModuleV3.Publish'                                   = 'Publishing module {0} ({1}) to repository {2}' # $Module.Name, $Module.Version, $Repository.Name

	'Publish-PSFModule.Error.UnexpectedRepositoryType'           = 'Unexpected repository type: {0} of type {1}. This is likely a bug, please report it at "https://github.com/PowershellFrameworkCollective/PSFramework.NuGet/issues"' # $repositoryObject.Name, $repositoryObject.Type

	'Publish-PSFResourceModule.Error'                            = 'Failed to publish the resource module {0} to {1}' # $Name, ($Repository -join ', ')

	'Publish-StagingModule.Deploying.DeleteOld'                  = 'Cleaning up previously existing copy of {0} ({1})' # $module.Name, $version.Name
	'Publish-StagingModule.Deploying.Local'                      = 'Deploying {0} ({1}) to {2}' # $module.Name, $version.Name, $destination.Path
	'Publish-StagingModule.Deploying.Remote'                     = 'Deploying {1} ({2}) on {0} to {3}' # $TargetPath.ComputerName, $module.Name, $version.Name, $targetVersionRoot
	'Publish-StagingModule.Deploying.Remote.Failed'              = 'Failed to deploy {1} ({2}) on {0} to {3}: {4}' # $TargetPath.ComputerName, $module.Name, $version.Name, $targetVersionRoot, $deployResult.Error
	'Publish-StagingModule.Deploying.RenameOld'                  = 'Renaming previously existing copy of {0} ({1})' # $module.Name, $version.Name
	'Publish-StagingModule.Error.General'                        = 'An error happened when deploying to {0}' # $TargetPath.ComputerName
	'Publish-StagingModule.Remote.Deploying.RenameOld'           = 'Renaming previously existing copy of {1} ({2}) on {0} at {3}' # $TargetPath.ComputerName, $module.Name, $version.Name, $testPath
	'Publish-StagingModule.Remote.Deploying.RenameOld.NoSuccess' = 'Failed to rename previously existing copy of {1} ({2}) on {0} at {3}: {4}' # $TargetPath.ComputerName, $module.Name, $version.Name, $testPath, $renameResult.Error
	'Publish-StagingModule.Remote.Deploying.RenameOld.Success'   = 'Successfully renamed previously existing copy of {1} ({2}) on {0} at {3}.' # $TargetPath.ComputerName, $module.Name, $version.Name, $testPath
	'Publish-StagingModule.Remote.DeployStaging'                 = 'Deploying {1} ({2}) on {0} to staging directory {3}' # $TargetPath.ComputerName, $module.Name, $version.Name, $targetStagingRoot
	'Publish-StagingModule.Remote.DeployStaging.FailedCopy'      = 'Failed to deploy {1} ({2}) on {0} to staging directory {3}. Staging directory could not be created: {4}' # $TargetPath.ComputerName, $module.Name, $version.Name, $targetStagingRoot
	'Publish-StagingModule.Remote.DeployStaging.FailedDirectory' = 'Failed to deploy {1} ({2}) on {0} to staging directory {3}.' # $TargetPath.ComputerName, $module.Name, $version.Name, $targetStagingRoot, $createResult.Error
	'Publish-StagingModule.Remote.Error.TempStagingSetup'        = 'Failed to setup the staging folder on {0}: {1}' # $TargetPath.ComputerName, $stagingResult.Error
	'Publish-StagingModule.Remote.Skipping.AlreadyExists'        = 'Skipping deploying {1} ({2}) - already exists on {0}' # $TargetPath.ComputerName, $module.Name, $version.Name
	'Publish-StagingModule.Skipping.AlreadyExists'               = 'Skipping module {0} ({1}): Already exists in target {2}' # $module.Name, $version.Name, $destination.Path

	'Read-ManifestDependency.Warning.VersionError'               = 'Invalid RequiredModules in manifest {0}: The version on {1} is not correct' # $Path, $requirement.Name

	'Read-VersionString.Error.BadFormat'                         = 'Bad version filter format: {0}. The version format requires a %Version%-%Version% format with either version number optional. The notation may be encapsuled by parenthesis or square brackets and nothing else.' # $Version
	'Read-VersionString.Error.BadFormat.ZeroUpperBound'          = 'Bad version filter format: {0}. The upper bound version limit cannot be "0.0.0"!' # $Version

	'Resolve-ModuleScopePath.Error.NotFound'                     = 'Failed to resolve paths on {0}: {1}' # $result.ComputerName, (@($result.Results).Where{ -not $_.Exists }.Path -join ' | ')
	'Resolve-ModuleScopePath.Error.ScopeNotFound'                = 'Module installation scope not found: {0}. Known scopes: {1}' # $Scope, ((Get-PSFModuleScope).Name -join ', ')
	'Resolve-ModuleScopePath.Error.UnReached'                    = 'Unable to resolve scope paths - computer not reached: {0} ({1})' # $result.ComputerName, ($result.Path -join ' | ')
	'Resolve-ModuleScopePath.Fail.NotAll'                        = 'Failed to resolve scope paths for all computers. Failed targets: {0}' # (@($testResult).Where{-not $_.Success }.ComputerName -join ' | ')
	'Resolve-ModuleScopePath.Fail.NotAny'                        = 'Failed to resolve scope paths for any computers. {0}' # ($testResult.ComputerName -join ' | ')

	'Resolve-RemotePath.Error.NotFound'                          = 'Reached {0} but was unable to resolve paths {1}' # $result.ComputerName, (@($result.Results).Where{ -not $_.Exists }.Path -join ' | ')
	'Resolve-RemotePath.Error.UnReached'                         = 'Failed to reach {0}, unable to resolve paths {1}' # $result.ComputerName, ($Path -join ' | ')
	'Resolve-RemotePath.Fail.NotAll'                             = 'Failed to successfully resolve paths on {0} > {1}' # (@($testResult).Where{-not $_.Success }.ComputerName -join ' | '), ($Path -join ' | ')
	'Resolve-RemotePath.Fail.NotAny'                             = 'Failed to successfully resolve paths on {0} > {1}' # ($testResult.ComputerName -join ' | '), ($Path -join ' | ')

	'Resolve-Repository.Error.NoRepo'                            = 'Failed to find repository {0} of type {1}' # ($Name -join ', '), $Type

	'Save-PowerShellGet.Error.UnableToResolve'                   = 'Unable to resolve aka.ms link: {0}. Make sure internet access is available!' # $link

	'Save-PSFModule.Error.NoComputerValid'                       = 'Failed to connect to any of the provided computer targets: {0}' # ($ComputerName -join ', ')

	'Save-PSFResourceModule.Deploying'                           = 'Deploying {2} from resource module {0} ({1}) to {3}' # $module.Name, $versionFolder.Name, $item.Name, $pathEntry
	'Save-PSFResourceModule.Downloading'                         = 'Downloading resource modules {0}' # ($Name -join ', ')
	'Save-PSFResourceModule.Skipping.AlreadyExists'              = 'Skipping transfer of {2} from resource module {0} ({1}) - already exists as {3}' # $module.Name, $versionFolder.Name, $item.Name, $pathEntry
	'Save-PSFResourceModule.Skipping.InvalidResource'            = 'Invalid resource module: {0} ({1}). It does not contain the expected "Resources" folder. Make sure the resource module has been published using Publish-PSFResourceModule' # $module.Name, $versionFolder.Name

	'Save-StagingModule.Error.SaveFailed'                        = 'Failed to retrieve module {0} ({1}) from any of the following repositories: {2}' # $installItem.Name, $installItem.Version, (@($repository).ForEach{ '{0} ({1})' -f $_.Name, $_.Type } -join ', ')
	'Save-StagingModule.Error.UnknownRepoType'                   = 'Unexpected repository type {0} on repository {1}. This is probably an implementation but, please report it at "https://github.com/PowershellFrameworkCollective/PSFramework.NuGet/issues"' # $repository.Type, $repository.Name
	'Save-StagingModule.SavingV2.Done'                           = 'Finished download of {1} ({2}) from repository {3} of type {4}. Success: {0}' # $result.Success, $Item.Name, $Item.Version, $Repository.Name, $Repository.Type
	'Save-StagingModule.SavingV2.Error.DependencyCleanup'        = 'Failed to remove undesired temporary dependencies for {1} ({2}) from repository {3} of type {4}' # $Item.Name, $Item.Version, $Repository.Name, $Repository.Type
	'Save-StagingModule.SavingV2.Error.Download'                 = 'Failed to download module {0} ({1}) from repository {2} of type {3}' # $Item.Name, $Item.Version, $Repository.Name, $Repository.Type
	'Save-StagingModule.SavingV2.Error.Transfer'                 = 'Failed to transfer module {0} ({1}) from repository {2} of type {3} to the staging folder.' # $Item.Name, $Item.Version, $Repository.Name, $Repository.Type
	'Save-StagingModule.SavingV2.Error.Unsigned'                 = 'Failed to verify signature of module {0} ({1}) or any of its dependencies from repository {2} of type {3}' # $Item.Name, $Item.Version, $Repository.Name, $Repository.Type
	'Save-StagingModule.SavingV2.SignatureCheck'                 = 'Signature validation. Module {0} ({1}) is signed correctly: {2}' # $signature.Name, $signature.Version, $signature.IsSigned
	'Save-StagingModule.SavingV2.Start'                          = 'Starting the download of {0} ({1}) from repository {2} of type {3}' # $Item.Name, $Item.Version, $Repository.Name, $Repository.Type
	'Save-StagingModule.SavingV3.Done'                           = 'Finished download of {1} ({2}) from repository {3} of type {4}. Success: {0}' # $result.Success, $Item.Name, $Item.Version, $Repository.Name, $Repository.Type
	'Save-StagingModule.SavingV3.Error.Download'                 = 'Failed to download module {0} ({1}) from repository {2} of type {3}' # $Item.Name, $Item.Version, $Repository.Name, $Repository.Type
	'Save-StagingModule.SavingV3.Error.Transfer'                 = 'Failed to transfer module {0} ({1}) from repository {2} of type {3} to the staging folder.' # $Item.Name, $Item.Version, $Repository.Name, $Repository.Type
	'Save-StagingModule.SavingV3.Error.Unsigned'                 = 'Failed to verify signature of module {0} ({1}) or any of its dependencies from repository {2} of type {3}' # $Item.Name, $Item.Version, $Repository.Name, $Repository.Type
	'Save-StagingModule.SavingV3.SignatureCheck'                 = 'Signature validation. Module {0} ({1}) is signed correctly: {2}' # $signature.Name, $signature.Version, $signature.IsSigned
	'Save-StagingModule.SavingV3.Start'                          = 'Starting the download of {0} ({1}) from repository {2} of type {3}' # $Item.Name, $Item.Version, $Repository.Name, $Repository.Type

	'Update-PSFModuleManifest.Error.BadManifest'                 = 'Invalid module manifest {0} ({1}): Manifest must at least contain "ModuleVersion" and "RootModule"' # (Get-Item -Path $Path).BaseName, $Path
	'Update-PSFModuleManifest.Error.InvalidModuleReference'      = 'Invalid Module Reference - the module specification does not contain a valid module name: {0}. It should either be a string or a hashtable with a "ModuleName" key.' # $item

	'Update-PSFRepository.Error.InvalidType'                     = 'Failed to compare repository types - unexpected Type configured: {0}. Supported types: {1}. Use this to see the configured repository types: "Get-PSFConfig -FullName PSFramework.NuGet.Repositories.*.Type"' # $configuredRepo.Type, ($supportedTypes -join ', ')
	'Update-PSFRepository.Register.Failed'                       = 'Failed to refister the {0} repository {1} ({2})' # V2, $param.Name, $uri
	'Update-PSFRepository.Repository.Unregister'                 = 'Unregistering the {0} repository {1}' # $change.Actual.Type, $Change.Actual.Name
	'Update-PSFRepository.Repository.Update'                     = 'Updating the settings on the {0} repository {1}. Settings changed: {2}' # $change.Actual.Type, $Change.Actual.Name, ($param.Keys -join ',')
}