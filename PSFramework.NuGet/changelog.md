# Changelog

## ???

+ Upd: Updated to include PSResourceGet 1.1.0
+ Upd: Get-PSFPowerShellGet - improved result display style
+ Fix: Install-PSFModule - returns unexpected object when successfully installing, but not from the first priority repository
+ Fix: Install-PSFModule - progress bar does not show number of deployments in progress.
+ Fix: Scope: AllUsers - fails to install to AllUsers when no module has been installed there yet.

## 0.9.2 (2025-01-17)

+ Fix: Get-PSFRepository - writes error when searching for a specific repository that only exists in one PSGet version
+ Fix: Update-PSFRepository - will update the "Trusted" status of a configured repository, even if the base properties have not yet been configured

## 0.9.0 (2025-01-03)

+ Initial Preview Release
