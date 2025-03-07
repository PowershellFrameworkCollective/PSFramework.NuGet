﻿<#
Add all things you want to run after importing the main function code

WARNING: ONLY provide paths to files!

After building the module, this file will be completely ignored, adding anything but paths to files ...
- Will not work after publishing
- Could break the build process
#>

$moduleRoot = Split-Path (Split-Path $PSScriptRoot)

# Load Configurations
(Get-ChildItem "$moduleRoot\internal\configurations\*.ps1" -ErrorAction Ignore).FullName

# Load Scriptblocks
(Get-ChildItem "$moduleRoot\internal\scriptblocks\*.ps1" -ErrorAction Ignore).FullName

# Load Tab Expansion
(Get-ChildItem "$moduleRoot\internal\tepp\*.tepp.ps1" -ErrorAction Ignore).FullName

# Load Tab Expansion Assignment
"$moduleRoot\internal\tepp\assignment.ps1"

"$moduleRoot\internal\scripts\variables.ps1"
"$moduleRoot\internal\scripts\initialize.ps1"

# Load License
"$moduleRoot\internal\scripts\license.ps1"

# Load Module Scopes
(Get-ChildItem "$moduleRoot\internal\moduleScopes\*.ps1" -ErrorAction Ignore).FullName
"$moduleRoot\internal\scripts\persistedScopes.ps1"