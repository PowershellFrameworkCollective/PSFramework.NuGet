# PSFramework.NuGet

> Preview Warning:
> This module is made available in a Preview version.
> Given the complexity involved, changes are expected before the first "stable" release, given that it is impossible to catch all eventualities and bugs out of the box.

## Description

Welcome to the `PSFramework.NuGet` module, a project to provide sane package management.
Its purpose is to make it a simple, convenient experience to install and deploy PowerShell modules and the tools we need to do it.

Feature-Set:

+ Simply install modules, using any kind of Package Management module and repository available
+ Bootstrap offline computer for package management
+ Manage repositories by policy / configuration
+ Simplify credential use
+ Install modules to remote computers via PSRemoting
+ Customize Module Scopes for Installation

> Example use

For example, when you wanted to install a module, depending on which version you had available, you would originally call:

+ PowerShellGet v1-2: `Install-Module`
+ PowerShellGet v3+ (Microsoft.PowerShell.PSResourceGet): `Install-PSResource`

With the `PSFramework.NuGet` module, in both scenarios you would instead use:

```powershell
Install-PSFModule 'MyModule'
```

But now you can also do something like this:

```powershell
Install-PSFModule 'MyModule' -ComputerName server1, server2
```

Or this:

```powershell
$sessions = New-PSSession -VMName server1, server2, -Credential $cred
Install-PSFModule 'MyModule' -ComputerName $sessions
```

## Installation

To install this module, run ...

```powershell
Install-Module PSFramework.NuGet -Scope CurrentUser
```

Of course, problem here is that if you want to use this module, this very line might be failing already!
So, here is a way to bootstrap your current console without requiring PowerShellGet to already function:

```powershell
iwr https://raw.githubusercontent.com/PowershellFrameworkCollective/PSFramework.NuGet/refs/heads/master/bootstrap.ps1 -UseBasicParsing | iex
```

> Update the Tooling

This toolkit tries to help make module installation go smoothly with as little effort for you as possible.
However, it still uses the official Microsoft Modules to download and modules for maximum compatibility.
If some of the things you want to work still will not, you may need to update your PowerShellGet modules, which can be done with this line:

```powershell
Install-PSFPowerShellGet -Type V2Binaries, V2Latest, V3Latest
```

After that line, start a new console and you should be up-to-date on all your tools needed.

## Features

### Module Installation (Local or Remote)

Simple Installation:

```powershell
Install-PSFModule 'MyModule'
```

Deploy via remoting (only local computer needs repository access):

```powershell
Install-PSFModule 'MyModule' -ComputerName server1, server2
```

Deploy via already existing remoting session:

```powershell
$sessions = New-PSSession -VMName server1, server2, -Credential $cred
Install-PSFModule 'MyModule' -ComputerName $sessions
```

Even on PowerShellGet V2 or older, this will now work:

```powershell
Install-PSFModule 'MyModule' -SkipDependenciesCheck
```

Install a module from PowerShell 7, that is available on both WinPS & PS7:

```powershell
Install-PSFModule 'MyModule' -Scope AllUsersWinPS
```

### Deploying PowerShellGet & PSResourceGet

One of the classic problems:
To use `Install-Module` you first need to either bootstrap the preinstalled version or update to the latest version of PowerShellGet.
However, the bootstrap requires internet (problematic on an offline server) and the module update required PowerShellGet to already work - the classic Chicken-Egg problem.

So lets fix this:

```powershell
# Bootstrap Binaries for old Versions
Install-PSFPowerShellGet -Type V2Binaries -ComputerName server1, server2, server3

# Install Latest V2
Install-PSFPowerShellGet -Type V2Latest -ComputerName $sessions

# Install Latest V3
Install-PSFPowerShellGet -Type V3Latest -ComputerName $sessions
```

None of these require internet access, so long as `PSFramework.NuGet` is available.
On that note, it is equally possible to distribute `PSFramework.NuGet` at scale, but that requires a PowerShell repository to be available.

```powershell
# Install PSFramework.NuGet on all machines
Install-PSFModule -Name PSFramework.NuGet -ComputerName $sessions
```

### Deploying Files & Folders as Resource Modules

Sometimes we might want to deploy non-Module files & folders using the same mechanism as modules.
For example, a module that provides templating might want to offer commands such as `Install-Template`, `Publish-Template` or `Find-Template`.

This is also provided for by this module:

```powershell
# Publish files as a Resource Module
Publish-PSFResourceModule -Name MyModule.Template.MyFunction -Version 1.1.0 -Path .\MyFunction\* -Repository PSGallery -ApiKey $key

# Download and extract the files
Save-PSFResourceModule -Name MyModule.Template.MyFunction -Path .
```

### ModuleScopes

Install-Module and Install-PSResource both offer two scopes to select where to install to:
`AllUsers` and `CurrentUser`.

These same options exist with `Install-PSFModule` but ... with the remoting capabilities and non-Windows OSes, a more flexible system became necessary.
For example, here is how `AllUsers` is implemented in `PSFramework.NuGet`:

```powershell
$code = {
    if ($PSVersionTable.PSVersion.Major -le 5) {
        return "$([Environment]::GetFolderPath("ProgramFiles"))\WindowsPowerShell\Modules"
    }
    if ($IsWindows) {
        return "$([Environment]::GetFolderPath("ProgramFiles"))\PowerShell\Modules"
    }
    '/usr/local/share/powershell/Modules'
}
$scopeParam = @{
    Name = 'AllUsers'
    ScriptBlock = $code
    Description = 'Default path for modules visible to all users.'
}
Register-PSFModuleScope @scopeParam
```

This way, even while installing to multiple remote systems _in parallel_ (`Install-PSFModule` multithreads using Runspaces), each computer will have it installed to the correct location, Windows or not.

> Static Paths

Of course, a static scope can be defined as well:

```powershell
Register-PSFModuleScope -Name Personal -Path C:\code\Modules -Description 'Personal local modules, not redirected to OneDrive documents'
Install-PSFModule -Name EntraAuth -Scope Personal
```

And to avoid having to do that again each time you start PowerShell - and to avoid having to put it into your $profile and force the module import into your console start - you can make PowerShell remember your choice:

```powershell
Register-PSFModuleScope -Name Personal -Path C:\code\Modules -Description 'Personal local modules, not redirected to OneDrive documents' -Persist
```

> Overriding defaults

This same can be used to override the default scopes if desired.
By default, when not specifying a scope or ComputerName, it will use the `CurrentUser` scope, no matter how that scope is configured.

```powershell
# This too can be persisted
Register-PSFModuleScope -Name CurrentUser -Path C:\code\Modules -Description 'Personal local modules, not redirected to OneDrive documents' -Persist

# Will now install to C:\code\Modules
Install-PSFModule -Name EntraAuth
```

### Configuring Repositories

Working with private repositories can be a bit of an annoyance.
Especially when you need to remember to always provide credentials with each request.

So, let's make this pain go away:

```powershell
# For the current session
Set-PSFRepository -Name AzDevOps -Credential $patCred

# Remember it going forward
Set-PSFRepository -Name AzDevOps -Credential $patCred -Persist
```

> Deploy repositories by policy

Another pain is teaching each and every computer on where to get their modules.
Fortunately you can deploy them by using the [PSFramework Configuration System](https://psframework.org/documentation/documents/psframework/configuration.html).
There are several options to that, whether deploying a configuration file to the expected location, a registry key or even environment variables.

Example configuration Set for the repository-name "AzDevOps":

```text
PSFramework.NuGet.Repositories.AzDevOps.Uri: <url>
PSFramework.NuGet.Repositories.AzDevOps.Priority: 40
PSFramework.NuGet.Repositories.AzDevOps.Type: Any
PSFramework.NuGet.Repositories.AzDevOps.Trusted: 1
```

Or an example deployed to HKLM:

```text
Key: HKLM:\SOFTWARE\Microsoft\WindowsPowerShell\PSFramework\Config\Default
```

Values:

|Name|Type|Value|
|---|---|---|
|PSFramework.NuGet.Repositories.AzDevOps.Uri|REG_SZ|String:<url>|
|PSFramework.NuGet.Repositories.AzDevOps.Priority|REG_SZ|Int:40|
|PSFramework.NuGet.Repositories.AzDevOps.Type|REG_SZ|String:Any|
|PSFramework.NuGet.Repositories.AzDevOps.Trusted|REG_SZ|Int:1|
