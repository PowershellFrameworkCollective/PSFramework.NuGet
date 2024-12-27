<#
This is an example configuration file

By default, it is enough to have a single one of them,
however if you have enough configuration settings to justify having multiple copies of it,
feel totally free to split them into multiple files.
#>

<#
# Example Configuration
Set-PSFConfig -Module 'PSFramework.NuGet' -Name 'Example.Setting' -Value 10 -Initialize -Validation 'integer' -Handler { } -Description "Example configuration setting. Your module can then use the setting using 'Get-PSFConfigValue'"
#>

Set-PSFConfig -Module 'PSFramework.NuGet' -Name 'Import.DoDotSource' -Value $false -Initialize -Validation 'bool' -Description "Whether the module files should be dotsourced on import. By default, the files of this module are read as string value and invoked, which is faster but worse on debugging."
Set-PSFConfig -Module 'PSFramework.NuGet' -Name 'Import.IndividualFiles' -Value $false -Initialize -Validation 'bool' -Description "Whether the module files should be imported individually. During the module build, all module code is compiled into few files, which are imported instead by default. Loading the compiled versions is faster, using the individual files is easier for debugging and testing out adjustments."

Set-PSFConfig -Module 'PSFramework.NuGet' -Name 'Install.AuthenticodeSignature.Check' -Value $false -Initialize -Validation 'bool' -Description 'Whether on installation or download of module its code-signing will be checked first.'
Set-PSFConfig -Module 'PSFramework.NuGet' -Name 'Remoting.DefaultConfiguration' -Value 'Microsoft.PowerShell' -Initialize -Validation string -Description 'The PSSessionConfiguration to use when initializing new PS remoting sessions'
Set-PSFConfig -Module 'PSFramework.NuGet' -Name 'Remoting.Throttling' -Value 5 -Initialize -Validation integerpositive -Description 'Up to how many remote computers to deploy to in parallel.'