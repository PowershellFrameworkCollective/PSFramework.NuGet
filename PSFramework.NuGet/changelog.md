# Changelog

## 0.9.16 (2025-05-17)

+ Upd: Install-PSFPowerShellGet - now allows bootstrapping localhost without requiring elevation.
+ Fix: Publish-PSFResourceModule - does not include files with brackets (`[]`) in their name.
+ Fix: Save-PSFResourceModule - does not include empty folders or files when using V3 repositories.
+ Fix: Find-PSFModule - fails (with error) when searching for prerelease versions on a default Windows PowerShell console without any modifications.

## 0.9.12 (2025-05-06)

+ Fix: Install-PSFModule - fails to install on a default Windows PowerShell console without any modifications.

## 0.9.11 (2025-05-05)

+ New: Bootstrap script to deploy PSFramework.NuGet to the local computer without requiring Package Management.
+ New: Module automatically deploys the NuGet provider to the user profile on module import, to simplify the PowerShellGet experience
+ Upd: Updated to include PSResourceGet 1.1.0
+ Upd: Get-PSFPowerShellGet - improved result display style
+ Fix: Install-PSFModule - fails to detect already existing version of module and attempts to overwrite
+ Fix: Install-PSFModule - returns unexpected object when successfully installing, but not from the first priority repository
+ Fix: Install-PSFModule - progress bar does not show number of deployments in progress.
+ Fix: Save-PSFModule - fails to detect already existing version of module and attempts to overwrite
+ Fix: Scope: AllUsers - fails to install to AllUsers when no module has been installed there yet.

## 0.9.2 (2025-01-17)

+ Fix: Get-PSFRepository - writes error when searching for a specific repository that only exists in one PSGet version
+ Fix: Update-PSFRepository - will update the "Trusted" status of a configured repository, even if the base properties have not yet been configured

## 0.9.0 (2025-01-03)

+ Initial Preview Release
