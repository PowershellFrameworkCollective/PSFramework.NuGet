function Update-PSFModuleManifest {
	<#
	.SYNOPSIS
		Modifies an existing module manifest.
	
	.DESCRIPTION
		Modifies an existing module manifest.
		The manifest in question must have a ModuleVersion and a RootModule entry present.
	
	.PARAMETER Path
		Path to the manifest file to modify.
	
	.PARAMETER Guid
		The guid of the module.
		Usually has no effect.
	
	.PARAMETER Author
		The author that wrote the module.
	
	.PARAMETER CompanyName
		The company that owns the module (if any).
	
	.PARAMETER Copyright
		The Copyright short-string.
		Example: 'Copyright (c) 2025 Contoso ltd.'
	
	.PARAMETER RootModule
		The root file of the module.
		For script based modules, that would be the psm1 file. For binary modules the root .dll file.
		Paths relative to the module root path.
		Examples:
		- MyModule.psm1
		- bin\MyModule.dll
	
	.PARAMETER ModuleVersion
		The version of the module.
		Most package services reject module uploads with versions that already exist in the service.
	
	.PARAMETER Description
		The description the module should include.
		A description is required for successful module uploads.
		Most package services use the description field to explain the module in their module lists.
	
	.PARAMETER ProcessorArchitecture
		The architecture thhe module requires.
		Do not provide unless you actually use hardware features for a specific architecture set.
	
	.PARAMETER CompatiblePSEditions
		What PowerShell editions this module is compatible with.
		- Desktop: Windows PowerShell
		- Core: PowerShell 6+
		Has little effect, other than documentation.
		When set to "Desktop"-only, loading the module into a core session will lead to it being imported into an implicit remoting session instead.
	
	.PARAMETER PowerShellVersion
		The minimum version of PowerShell to require for your module.
		There is no option to define a maximum version.
		To declare "this module only runs on Windows PowerShell" use -CompatiblePSEditions instead.
	
	.PARAMETER ClrVersion
		What minimum version of the Common Language Runtime you require.
		If this has you wondering "What is the Common Language Runtime" you do not need to specify this parameter.
		If it does not, you still probably won't need it.
	
	.PARAMETER DotNetFrameworkVersion
		What version of the .NET Framework to require as a minimum.
		A pointless requirement compared to requiring a minimum version of PowerShell.
		Usually not necessary.
	
	.PARAMETER PowerShellHostName
		What PowerShell host your module requires.
		This can enforce your module only being loaded into a specific hosting process, such as "This only works in the Powershell ISE".
		Use this to read the name you need to provide here:
		$host.Name
		Usually only useful for modules that act as PlugIn for the PowerShell ISE.

		Example values:
		- "ConsoleHost"
		- "Windows PowerShell ISE Host"
	
	.PARAMETER PowerShellHostVersion
		The minimum version of the host you require.
		Use this to read the current version of a host:
		$host.Version -as [string]
	
	.PARAMETER RequiredModules
		What modules your module requires to run.
		Taking a dependency like this means, that when someone installs your module, they also automatically
		download all the dependencies without needing additional input.
		Can either take a string or a hashtable with the default module definitions (see below):

		Examples:
		- "PSFramework" # any version of the PSFramework
		- @{ ModuleName = "PSFramework"; ModuleVersion = "1.2.346" } # The module "PSFramework" with AT LEAST version 1.2.346
		- @{ ModuleName = "PSFramework"; RequiredVersion = "1.2.346" } # The module "PSFramework" with EXACTLY version 1.2.346

		Generally it is recommended to NOT use "RequiredVersion" unless as an emergency stopgap while you try to fix a compatibility issue.
		Using "RequiredVersion" significantly raises the risk of conflict between modules taking a dependency on the same module.
		It also prevents updating the dependency independently, which your users may need to do (e.g. critical security patch) without waiting on you.

		Generally, it is recommended to be cautious about what module you take a dependency on, when you do not control the dependency.
		For non-public modules, you can minimize the risk of breaking things by having an internal repository and testing new versions
		of modules you take a dependency on, before introducing them into your environment.
	
	.PARAMETER TypesToProcess
		Type extension XML to load when importing the module.
		These allow you to add methods and properties to existing objects, without calling Add-Member on each of them.
		For more details, see: https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/extending-output-objects
	
	.PARAMETER FormatsToProcess
		Format definition XML to load when importing the module.
		These allow you to determine how objects your commands return should be displayed.
		For more details, see: https://learn.microsoft.com/en-us/powershell/scripting/developer/format/formatting-file-overview
		You can use the module PSModuleDevelopment and its "New-PSMDFormatTableDefinition" command to auto-generate the XML
		for your objects.
	
	.PARAMETER ScriptsToProcess
		Any scripts to run before your module imports.
		Any failure here will stop the module import.
		This should NOT be used to load nested files of your module project!
		Generally, this parameter is not needed, instead place the import sequence in your psm1 file.

		For an example layout that does that, check out the PSModuleDevelopment module's default module template:
		Invoke-PSMDTemplate MiniModule
	
	.PARAMETER RequiredAssemblies
		Assemblies you require.
		These DLL files will be loaded as part of your import sequence.
		Failure to do so (e.g. file not found, or dependency not found) will cause your module import to fail.
		Can be the name of an assembly from GAC or the relative path to the file within your module's folder layout.
	
	.PARAMETER FileList
		List of files your module contains.
		Documentation only, has no effect.
	
	.PARAMETER ModuleList
		The modules included in your module.
		Generally not needed.
	
	.PARAMETER FunctionsToExport
		What functions your module makes available.
		Functions are PowerShell-native commands written in script code and usually the main point of writing a module.
		You should not export '*', as that makes it hard for PowerShell to know what commands your module exposes.
		This will lead to issues with automatically importing it when just running a command by name from your module.
	
	.PARAMETER AliasesToExport
		What aliases your module makes available.
		Aliases not listed here will not lead to automatic module import if needed.
		Do not export '*'.
	
	.PARAMETER VariablesToExport
		Not really used, no point in doing so.
	
	.PARAMETER CmdletsToExport
		Cmdlets your module makes available.
		Cmdlets are PowerShell-native commands written in C#* and compiled into a .DLL
		This is usually only needed when writing a binary module in C# or a hybrid module with a significant
		portion of compiled code.

		*Usually. Technically, other languages are also possible, but they all must be compiled into an assembly.
	
	.PARAMETER DscResourcesToExport
		What DSC resources your module provides.
		If you are wondering what DSC (Desired State Configuration) is, you are probably missing out, but this parameter
		is not (yet) for you.
	
	.PARAMETER Tags
		Tags to include in your module.
		Modules in nuget repositories can be searched by their tag.
	
	.PARAMETER LicenseUri
		The link to the license your module uses.
		This will be shown in the PSGallery and is usually a good idea to include in your module manifest.
	
	.PARAMETER IconUri
		The link to the icon to display with your module.
		Only affects how the module is displayed in the PSGallery.
	
	.PARAMETER ProjectUri
		The link to your project.
		This will be shown in the PSGallery and is usually a good idea to include in your module manifest.
	
	.PARAMETER ReleaseNotes
		What changed in the latest version of your module?
		Either provide the change text or the link to where your changes are being tracked.
	
	.PARAMETER Prerelease
		The prerelease tag, such as "Alpha" or "RC1".
		Including this will hide your module in most repositories by flagging it as a prerelease version.
		Only uses who include "-AllowPrerelease" in their Install-PSFModule call will install this version.
		Adding this is a good way to provide a test preview power users can test, without affecting the broader audience right away.
	
	.PARAMETER ExternalModuleDependencies
		Modules your own module requires, that are not distributed via powershell repositories.
		For example, if your module requires the "ActiveDirectory" module, this is the place to specify it.
		Generally only needed for modules not distribtued via gallery, such as RSAT tools to manage windows features or
		vendor modules that require you to deploy the module via installer.

		Uses the same module notation syntax as "-RequiredModules".
	
	.PARAMETER HelpInfoUri
		Where to get more information about your module.
	
	.PARAMETER DefaultCommandPrefix
		Default prefix to include with commands in your module.
		Generally not recommended for use.
	
	.PARAMETER NestedModules
		DO NOT USE.
		DON'T.
		IT'S A MISTAKE.
		CEASE AND DESIST!

		Nested modules allow you to include a module inside of your own module, which will be invisible to outsiders.
		Compared to traditional dependencies via RequiredModules this has the advantage of you getting EXACTLY the version
		you are expecting.
		Theoretically, this sounds good - it gives you the full control over what module version, zero risk of accidental breakage
		when the original author updates the module.
		Right?
		Not really.

		The key issue is, that most modules cannot coexist in different versions of the same module in the same process or at
		least runspace. The module you include as a NestedModule can - and WILL - still conflict with other modules requiring
		the same dependency.
		So you still get all the same version conflicts a RequiredModule with "RequiredVersion" defined has, but with horribly
		worse error message to the user (who is not aware of a potential conflict AND IS NOT INFORMED OF A CONFLICT!!!).
		
		By whatever is holy, sacred or venerable to you, please do not use NestedModules.
	
	.PARAMETER PassThru
		Rather than modifying the file, return the new manifest text as string.
	
	.PARAMETER Cmdlet
		The PSCmdlet variable of the calling command, used to ensure errors happen within the scope of the caller, hiding this command from the user.
	
	.PARAMETER Continue
		In case of error, when not specifying ErrorAction as stop, this command will call the continue statement.
		By default, it will just end with a warning.
		This parameter makes it easier to integrate in some flow control scenarios but is mostly intended for internal use only.
	
	.EXAMPLE
		PS C:\> Update-PSFModuleManifest -Path .\MyModule\MyModule.psd1 -FunctionsToExport $functions.BaseName
		
		Updates MyModule.psd1 to export the functions stored in $functions.
		This will _replace_ the existing entries.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[PsfValidateScript('PSFramework.Validate.FSPath.File', ErrorString = 'PSFramework.Validate.FSPath.File')]
		[string]
		$Path,

		[guid]
		$Guid,

		[string]
		$Author,

		[string]
		$CompanyName,

		[string]
		$Copyright,

		[string]
		$RootModule,
		
		[version]
		$ModuleVersion,

		[string]
		$Description,

		[ValidateSet('', 'X86', 'Amd64')]
		[string]
		$ProcessorArchitecture,

		[ValidateSet('Core', 'Desktop')]
		[string[]]
		$CompatiblePSEditions,

		[version]
		$PowerShellVersion,
		
		[version]
		$ClrVersion,

		[version]
		$DotNetFrameworkVersion,

		[string]
		$PowerShellHostName,

		[version]
		$PowerShellHostVersion,

		[object[]]
		$RequiredModules,

		[string[]]
		$TypesToProcess,

		[string[]]
		$FormatsToProcess,

		[string[]]
		$ScriptsToProcess,

		[string[]]
		$RequiredAssemblies,

		[string[]]
		$FileList,

		[object[]]
		$ModuleList,

		[string[]]
		$FunctionsToExport,

		[string[]]
		$AliasesToExport,

		[string[]]
		$VariablesToExport,

		[string[]]
		$CmdletsToExport,

		[string[]]
		$DscResourcesToExport,

		[string[]]
		$Tags,
		
		[string]
		$LicenseUri,
		
		[string]
		$IconUri,

		[string]
		$ProjectUri,

		[string]
		$ReleaseNotes,

		[string]
		$Prerelease,

		[object[]]
		$ExternalModuleDependencies,

		[uri]
		$HelpInfoUri,

		[string]
		$DefaultCommandPrefix,

		[object[]]
		$NestedModules,

		[switch]
		$PassThru,

		[Parameter(DontShow = $true)]
		$Cmdlet = $PSCmdlet,

		[Parameter(DontShow = $true)]
		[switch]
		$Continue
	)
	begin {
		#region Utility Functions
		function ConvertTo-ModuleRequirement {
			[OutputType([System.Collections.Specialized.OrderedDictionary])]
			[CmdletBinding()]
			param (
				[Parameter(ValueFromPipeline = $true)]
				[AllowEmptyCollection()]
				[AllowNull()]
				[AllowEmptyString()]
				$InputObject,

				[bool]
				$EnableException,

				$Cmdlet
			)
			process {
				foreach ($item in $InputObject) {
					if (-not $item) { continue }

					if ($item -is [string]) { $item; continue }

					if (-not $item.ModuleName) {
						Stop-PSFFunction -String 'Update-PSFModuleManifest.Error.InvalidModuleReference' -StringValues $item -Target $item -EnableException $EnableException -Cmdlet $Cmdlet -Category InvalidArgument -Continue
					}

					$data = [ordered]@{ ModuleName = $item.ModuleName }
					if ($item.RequiredVersion) { $data.RequiredVersion = '{0}' -f $item.RequiredVersion }
					elseif ($item.ModuleVersion) { $data.ModuleVersion = '{0}' -f $item.ModuleVersion }

					$data
				}
			}
		}
		function Update-ManifestProperty {
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
			[OutputType([System.Management.Automation.Language.ScriptBlockAst])]
			[CmdletBinding()]
			param (
				[Parameter(Mandatory = $true)]
				[System.Management.Automation.Language.Ast]
				$Ast,

				[Parameter(Mandatory = $true)]
				[string]
				$Property,

				[Parameter(Mandatory = $true)]
				$Value,

				[Parameter(Mandatory = $true)]
				[ValidateSet('String', 'StringArray', 'HashtableArray')]
				[string]
				$Type
			)

			$mainHash = $Ast.FindAll({
					$args[0] -is [System.Management.Automation.Language.HashtableAst] -and
					$args[0].KeyValuePairs.Item1.Value -contains 'RootModule' -and
					$args[0].KeyValuePairs.Item1.Value -Contains 'ModuleVersion'
				}, $true)

			$entry = $mainhash.KeyValuePairs | Where-Object { $_.Item1.Value -eq $Property }
			$stringValue = switch ($Type) {
				'String' { "$Value" | ConvertTo-Psd1 }
				'StringArray' { , @(, @($Value)) | ConvertTo-Psd1 }
				'HashtableArray' { , @(, @($Value)) | ConvertTo-Psd1 }
			}
			$format = '{0}'
			#region Case: Key Already Exists
			if ($entry) {
				$start = $entry.Item2.Extent.StartOffset
				$end = $entry.Item2.Extent.EndOffset
			}
			#endregion Case: Key Already Exists

			#region Case: Key Does not exist
			else {
				$line = $Ast.Extent.Text -split "`n" | Where-Object { $_ -match "#\s+$Property = " }
				# Entry already exists but is commented out
				if ($line) {
					$format = "$Property = {0}"
					$index = $Ast.Extent.Text.IndexOf($line)
					$start = $index + $line.Length - $line.TrimStart().Length
					$end = $index + $line.Length
				}
				# Entry does not exist already
				else {
					$indent = ($Ast.Extent.Text -split "`n" | Where-Object { $_ -match "^\s+ModuleVersion" }) -replace '^(\s*).+$', '$1'
					$format = "$($indent)$($Property) = {0}`n"
					$start = $mainHash.Extent.EndOffset - 1
					$end = $mainHash.Extent.EndOffset - 1
				}
			}
			#endregion Case: Key Does not exist

			$newText = $Ast.Extent.Text.SubString(0, $start) + ($format -f $stringValue) + $Ast.Extent.Text.SubString($end)
			[System.Management.Automation.Language.Parser]::ParseInput($newText, [ref]$null, [ref]$null)
		}
		
		function Update-PrivateDataProperty {
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
			[OutputType([System.Management.Automation.Language.ScriptBlockAst])]
			[CmdletBinding()]
			param (
				[Parameter(Mandatory = $true)]
				[System.Management.Automation.Language.Ast]
				$Ast,

				[string[]]
				$Tags,
				
				[string]
				$LicenseUri,
				
				[string]
				$IconUri,
				
				[string]
				$ProjectUri,

				[string]
				$ReleaseNotes,

				[string]
				$Prerelease,

				[object[]]
				$ExternalModuleDependencies,

				[bool]
				$EnableException,
				$Cmdlet
			)

			$mainHash = $Ast.FindAll({
					$args[0] -is [System.Management.Automation.Language.HashtableAst] -and
					$args[0].KeyValuePairs.Item1.Value -contains 'RootModule' -and
					$args[0].KeyValuePairs.Item1.Value -Contains 'ModuleVersion'
				}, $true)

			$privateData = [ordered]@{
				PSData = [ordered]@{ }
			}
			$replacements = @{ }
	
			$privateDataAst = $mainHash.KeyValuePairs | Where-Object { $_.Item1.Value -eq 'PrivateData' } | ForEach-Object { $_.Item2.PipelineElements[0].Expression }

			if ($privateDataAst) {
				foreach ($pair in $privateDataAst.KeyValuePairs) {
					if ($pair.Item1.Value -ne 'PSData') {
						$id = "%PSF_$(Get-Random)%"
						$privateData[$pair.Item1.Value] = $id
						$replacements[$id] = $pair.Item2.Extent.Text
						continue
					}

					foreach ($subPair in $pair.Item2.PipelineElements[0].Expression.KeyValuePairs) {
						$id = "%PSF_$(Get-Random)%"
						$privateData.PSData[$subPair.Item1.Value] = $id
						$replacements[$id] = $subPair.Item2.Extent.Text
					}
				}
			}

			if ($Tags) { $privateData.PSData['Tags'] = $Tags }
			if ($LicenseUri) { $privateData.PSData['LicenseUri'] = $LicenseUri }
			if ($IconUri) { $privateData.PSData['IconUri'] = $IconUri }
			if ($ProjectUri) { $privateData.PSData['ProjectUri'] = $ProjectUri }
			if ($ReleaseNotes) { $privateData.PSData['ReleaseNotes'] = $ReleaseNotes }
			if ($Prerelease) { $privateData.PSData['Prerelease'] = $Prerelease }
			if ($ExternalModuleDependencies) { $privateData.PSData['ExternalModuleDependencies'] = ConvertTo-ModuleRequirement -InputObject $ExternalModuleDependencies -Cmdlet $Cmdlet -EnableException $EnableException }

			$privateDataString = $privateData | ConvertTo-Psd1 -Depth 5
			foreach ($pair in $replacements.GetEnumerator()) {
				$privateDataString = $privateDataString -replace "'$($pair.Key)'", $pair.Value
			}

			if (-not $privateDataAst) {
				$newManifest = $ast.Extent.Text.Insert(($mainHash.Extent.EndOffset - 1), "PrivateData = $privateDataString`n")
			}
			else {
				$newManifest = $ast.Extent.Text.SubString(0, $privateDataAst.Extent.StartOffset) + $privateDataString + $ast.Extent.Text.SubString($privateDataAst.Extent.EndOffset)
			}
			[System.Management.Automation.Language.Parser]::ParseInput($newManifest, [ref]$null, [ref]$null)
		}
		#endregion Utility Functions
	}
	process {
		$killIt = $ErrorActionPreference -eq 'Stop'

		$ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)

		$mainHash = $ast.FindAll({
				$args[0] -is [System.Management.Automation.Language.HashtableAst] -and
				$args[0].KeyValuePairs.Item1.Value -contains 'RootModule' -and
				$args[0].KeyValuePairs.Item1.Value -Contains 'ModuleVersion'
			}, $true)

		if (-not $mainHash) {
			Stop-PSFFunction -String 'Update-PSFModuleManifest.Error.BadManifest' -StringValues (Get-Item -Path $Path).BaseName, $Path -Cmdlet $Cmdlet -EnableException $killIt -Continue:$Continue
			return
		}

		#region Main Properties
		$stringProperties = 'Guid', 'Author', 'CompanyName', 'Copyright', 'RootModule', 'ModuleVersion', 'Description', 'ProcessorArchitecture', 'PowerShellVersion', 'ClrVersion', 'DotNetFrameworkVersion', 'PowerShellHostName', 'PowerShellHostVersion', 'HelpInfoUri', 'DefaultCommandPrefix'
		foreach ($property in $stringProperties) {
			if ($PSBoundParameters.Keys -notcontains $property) { continue }
			$ast = Update-ManifestProperty -Ast $ast -Property $property -Value $PSBoundParameters.$property -Type String
		}
		$stringArrayProperties = 'CompatiblePSEditions', 'TypesToProcess', 'FormatsToProcess', 'ScriptsToProcess', 'RequiredAssemblies', 'FileList', 'FunctionsToExport', 'AliasesToExport', 'VariablesToExport', 'CmdletsToExport', 'DscResourcesToExport'
		foreach ($property in $stringArrayProperties) {
			if ($PSBoundParameters.Keys -notcontains $property) { continue }
			$ast = Update-ManifestProperty -Ast $ast -Property $property -Value $PSBoundParameters.$property -Type StringArray
		}
		$moduleProperties = 'RequiredModules', 'ModuleList', 'NestedModules'
		foreach ($property in $moduleProperties) {
			if ($PSBoundParameters.Keys -notcontains $property) { continue }
			$ast = Update-ManifestProperty -Ast $ast -Property $property -Value ($PSBoundParameters.$property | ConvertTo-ModuleRequirement -EnableException $killIt -Cmdlet $Cmdlet) -Type StringArray
		}
		#endregion Main Properties
		
		#region PrivateData Content
		if ($Tags -or $LicenseUri -or $IconUri -or $ProjectUri -or $ReleaseNotes -or $Prerelease -or $ExternalModuleDependencies) {
			$updateParam = $PSBoundParameters | ConvertTo-PSFHashtable -ReferenceCommand Update-PrivateDataProperty
			$updateParam.Cmdlet = $Cmdlet
			$updateParam.EnableException = $killIt
			$ast = Update-PrivateDataProperty -Ast $ast @updateParam
		}
		#endregion PrivateData Content

		if ($PassThru) { $ast.Extent.Text }
		else { $ast.Extent.Text | Set-Content -Path $Path }
	}
}