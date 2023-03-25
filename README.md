# PSFramework.NuGet

## Description

Welcome to the `PSFramework.NuGet` module, a wrapper around the PowerShellGet modules.
It is intended to help bootstrap package management and to provide an abstraction layer over the different versions of PowerShellGet.

For example, when you wanted to install a module, depending on which version you were using you would call:

+ PowerShellGet v1-2: `Install-Module`
+ PowerShellGet v3+: `Install-PSResource`

With the `PSFramework.NuGet` module, in both scenarios you would instead use:

```powershell
Install-PSFModule 'MyModule' 
```

## Installation

To install this module, run ...

```powershell
Install-Module PSFramework.NuGet -Scope CurrentUser
```

## Features

In general, this module provides ...

+ Unified Commands between PowerShellGet versions
+ Tools to bootstrap older PowerShellGet versions
+ Install Modules to remote computers
+ Wrapper Commands to use NuGet as a carrier vehicle for other types of packages from PowerShell
