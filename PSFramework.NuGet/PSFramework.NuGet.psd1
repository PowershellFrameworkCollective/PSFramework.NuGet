﻿@{
	# Script module or binary module file associated with this manifest
	RootModule        = 'PSFramework.NuGet.psm1'
	
	# Version number of this module.
	ModuleVersion     = '0.9.16'
	
	# ID used to uniquely identify this module
	GUID              = 'ad0f2a25-552f-4dd6-bd8e-5ddced2a5d88'
	
	# Author of this module
	Author            = 'Friedrich Weinmann'
	
	# Company or vendor of this module
	CompanyName       = ' '
	
	# Copyright statement for this module
	Copyright         = 'Copyright (c) 2024 Friedrich Weinmann'
	
	# Description of the functionality provided by this module
	Description       = 'A wrapper around the PowerShellGet modules'
	
	# Minimum version of the Windows PowerShell engine required by this module
	PowerShellVersion = '5.1'
	
	# Modules that must be imported into the global environment prior to importing
	# this module
	RequiredModules   = @(
		@{ ModuleName = 'PSFramework'; ModuleVersion = '1.12.346' }
		@{ ModuleName = 'ConvertToPsd1'; ModuleVersion = '1.0.1'}
	)
	
	# Assemblies that must be loaded prior to importing this module
	# RequiredAssemblies = @('bin\PSFramework.NuGet.dll')
	
	# Type files (.ps1xml) to be loaded when importing this module
	# TypesToProcess = @('xml\PSFramework.NuGet.Types.ps1xml')
	
	# Format files (.ps1xml) to be loaded when importing this module
	FormatsToProcess = @('xml\PSFramework.NuGet.Format.ps1xml')
	
	# Functions to export from this module
	FunctionsToExport = @(
		'Find-PSFModule'
		'Get-PSFModuleScope'
		'Get-PSFModuleSignature'
		'Get-PSFPowerShellGet'
		'Get-PSFRepository'
		'Install-PSFModule'
		'Install-PSFPowerShellGet'
		'Publish-PSFModule'
		'Publish-PSFResourceModule'
		'Register-PSFModuleScope'
		'Save-PSFModule'
		'Save-PSFPowerShellGet'
		'Save-PSFResourceModule'
		'Search-PSFPowerShellGet'
		'Set-PSFRepository'
		'Update-PSFModuleManifest'
		'Update-PSFRepository'
	)
	
	# Cmdlets to export from this module
	CmdletsToExport   = @()
	
	# Variables to export from this module
	VariablesToExport = @()
	
	# Aliases to export from this module
	AliasesToExport   = @()
	
	# List of all modules packaged with this module
	ModuleList        = @()
	
	# List of all files packaged with this module
	FileList          = @()
	
	# Private data to pass to the module specified in ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
	PrivateData       = @{
		
		#Support for PowerShellGet galleries.
		PSData = @{
			
			# Tags applied to this module. These help with module discovery in online galleries.
			Tags = @('nuget', 'modules', 'psresource')
			
			# A URL to the license for this module.
			LicenseUri = 'https://github.com/PowershellFrameworkCollective/PSFramework.NuGet/blob/master/LICENSE'
			
			# A URL to the main website for this project.
			ProjectUri = 'https://github.com/PowershellFrameworkCollective/PSFramework.NuGet'
			
			# A URL to an icon representing this module.
			# IconUri = ''
			
			# ReleaseNotes of this module
			# ReleaseNotes = ''
			
		} # End of PSData hashtable
		
	} # End of PrivateData hashtable
}