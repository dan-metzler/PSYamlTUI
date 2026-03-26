---
name: powershell-expert
description: "PowerShell expertise for Windows PowerShell 5.1 and PowerShell 7+ (Core). Activate for: (1) ANY PowerShell scripting or module work, (2) CI/CD pipeline automation, (3) Cross-platform scripting, (4) Module discovery and management, (5) Script debugging and optimization, (6) Best practices, performance, and security. Provides production-ready patterns, cross-version compatibility guidance, and professional scripting standards."
---

# PowerShell Expert

## Version Compatibility

### Windows PowerShell 5.1
- Windows-only, ships with Windows 10/11 and Server
- UTF-16LE default encoding — always specify `-Encoding UTF8` explicitly
- No `$IsWindows`, `$IsLinux`, `$IsMacOS` automatic variables
- No ternary operator or null-coalescing
- Required for some Windows-specific modules (GroupPolicy, WSUS, certain AD cmdlets)
- `Install-Module` via PowerShellGet v2

### PowerShell 7+ (Core)
- Cross-platform: Windows, Linux, macOS
- UTF-8 by default
- `$IsWindows`, `$IsLinux`, `$IsMacOS` automatic variables
- Ternary operator: `$x = $condition ? 'true' : 'false'`
- Null-coalescing: `$value = $null ?? 'default'`
- Null-conditional: `$length = $string?.Length`
- Parallel ForEach: `ForEach-Object -Parallel`
- `Install-PSResource` via PSResourceGet (7.4+)

### Compatibility Patterns
```powershell
# Version-safe platform detection (works in 5.1 and 7+)
$isWin = if ($PSVersionTable.PSVersion.Major -ge 6) { $IsWindows } else { $true }

# Version-safe null coalescing (5.1 compatible)
$value = if ($null -ne $input) { $input } else { 'default' }

# Check PS version at runtime
if ($PSVersionTable.PSVersion.Major -ge 7) {
    # PS7+ only code
} else {
    # 5.1 compatible fallback
}
```

---

## Script Structure

Always follow this structure for production scripts:
```powershell
<#
.SYNOPSIS
    Brief one-line description.

.DESCRIPTION
    Full description of what the script does, its requirements,
    and any important behavior to be aware of.

.PARAMETER Name
    Description of the parameter.

.EXAMPLE
    PS> .\script.ps1 -Name 'Value'
    Description of what this example does.

.NOTES
    Author: Name
    Version: 1.0.0
    Requires: PowerShell 5.1+
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter()]
    [ValidateRange(1, 100)]
    [int]$Count = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    Write-Verbose "Starting: $Name"
    # main logic here
}
catch {
    Write-Error "Failed: $_"
    exit 1
}
finally {
    # cleanup
}
```

---

## Functions

### Standard Function Template
```powershell
function Verb-Noun {
    <#
    .SYNOPSIS
        Brief description.
    .PARAMETER InputObject
        Description.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string[]]$InputObject,

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        # One-time setup
        $results = [System.Collections.Generic.List[string]]::new()
    }

    process {
        foreach ($item in $InputObject) {
            # Process each pipeline object
            $results.Add($item)
        }
    }

    end {
        $results
    }
}
```

### Key Rules
- Use approved verbs: `Get-Verb` lists all approved verbs
- Always add `[CmdletBinding()]` — enables `-Verbose`, `-WhatIf`, `-Confirm`
- Use `[OutputType()]` to declare what the function returns
- Use `begin/process/end` blocks for pipeline-aware functions
- Never use `return` mid-pipeline — use `Write-Output` or just emit the object

---

## Collections and Performance

### Prefer Generic Lists Over Arrays

Array concatenation (`+=`) recreates the entire array on every iteration — O(n²) performance. Always use Generic Lists for collections you build dynamically.
```powershell
# AVOID: Array concatenation — slow, recreates array each time
$results = @()
foreach ($item in $largeCollection) {
    $results += $item  # O(n²) — do not use
}

# PREFERRED: Generic List — type-safe, fast
$results = [System.Collections.Generic.List[string]]::new()
foreach ($item in $largeCollection) {
    $results.Add($item)
}

# Also acceptable: ArrayList — untyped but fast
# Use [void] to suppress the index integer Add() returns
$results = [System.Collections.ArrayList]::new()
foreach ($item in $largeCollection) {
    [void]$results.Add($item)
}

# For key-value lookups in hot paths, use Dictionary
$lookup = [System.Collections.Generic.Dictionary[string, object]]::new()
$lookup['key'] = $value
```

### When to Use Each Collection Type

| Type | Use When |
|------|----------|
| `@()` fixed array | Small, known-size collections that won't grow |
| `Generic List[T]` | Building collections dynamically — preferred default |
| `ArrayList` | Dynamic collections where type doesn't matter |
| `Dictionary[K,V]` | Key-value lookups replacing hashtable in hot paths |
| `@{}` hashtable | Configuration, splatting, small lookups |

### Suppressing Output
```powershell
[void]$list.Add($item)          # Preferred
$null = $list.Add($item)        # Also fine
$list.Add($item) | Out-Null     # Slowest — avoid in loops
```

---

## Hashtable Lookups vs Where-Object

`Where-Object` is a linear scan — O(n). Fine for one or two lookups against a small
collection. When you need repeated lookups, especially inside a loop, build a hashtable
index first for O(1) access.
```powershell
# WHERE-OBJECT — O(n) linear scan
# Fine for: small collections, one-off lookups
$item = $collection | Where-Object { $_.Name -eq 'target' }

# HASHTABLE INDEX — O(1) lookup
# Use when: looping and looking up repeatedly against the same collection

# Build the index once
$index = @{}
foreach ($item in $collection) {
    $index[$item.Name] = $item
}

# Look up as many times as needed — instant regardless of collection size
$item  = $index['target']
$other = $index[$inputValue]

# Real-world example: matching two lists without a nested loop
$userIndex = @{}
foreach ($user in $allUsers) {
    $userIndex[$user.SamAccountName] = $user
}

foreach ($entry in $importList) {
    $matched = $userIndex[$entry.SamAccountName]
    if ($matched) {
        # process match
    }
}
```

### Decision Rule

| Situation | Use |
|-----------|-----|
| 1–2 lookups against a collection | `Where-Object` — simpler, good enough |
| Repeated lookups inside a loop | Hashtable index — build once, look up many |
| Key-value data you control from the start | `@{}` hashtable directly — never put it in an array |
| High-volume lookups in hot paths | `Dictionary[K,V]` — faster than hashtable for large sets |

---

## Path Handling

Always use `Join-Path` or `[System.IO.Path]` — never concatenate paths manually.
```powershell
# PREFERRED: Join-Path (cross-platform, handles separators)
$configPath = Join-Path -Path $PSScriptRoot -ChildPath 'config.json'

# PS7+ supports multiple child paths in one call
$nested = Join-Path -Path $PSScriptRoot -ChildPath 'sub' -AdditionalChildPath 'file.txt'

# Also good: .NET Path class (works in 5.1 and 7+)
$path = [System.IO.Path]::Combine($PSScriptRoot, 'sub', 'file.txt')

# AVOID: Manual concatenation
$path = $PSScriptRoot + '\sub\file.txt'  # Windows-only
$path = "$PSScriptRoot\sub\file.txt"     # Windows-only

# Key path variables
$PSScriptRoot    # Directory of the current script — always prefer over $pwd
$PSCommandPath   # Full path to the current script file
```

---

## Error Handling
```powershell
# Always use -ErrorAction Stop on cmdlets inside try blocks
# Without it, non-terminating errors bypass the catch block
try {
    Get-Content -Path $path -ErrorAction Stop
    Invoke-RestMethod -Uri $url -ErrorAction Stop
}
catch [System.IO.FileNotFoundException] {
    Write-Error "File not found: $path"
}
catch [System.Net.WebException] {
    Write-Error "Network error: $_"
}
catch {
    # $_ is the ErrorRecord
    # $_.Exception.Message for just the message string
    Write-Error "Unexpected error: $_"
    throw  # Re-throw if the caller should handle it
}
finally {
    # Always runs — use for cleanup (connections, temp files, etc.)
}

# ErrorActionPreference scopes
$ErrorActionPreference = 'Stop'              # Treat all errors as terminating
$ErrorActionPreference = 'Continue'          # Default — log and continue
$ErrorActionPreference = 'SilentlyContinue' # Suppress — use sparingly

# Throwing typed exceptions
throw [System.ArgumentException]::new("Invalid value: $input")
throw [System.InvalidOperationException]::new("Not in valid state")
```

---

## Parameter Validation

Use validation attributes instead of manual `if`/`throw` checks in function bodies.
```powershell
param(
    # Not null or empty string/collection
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    # Must match one of these values (tab-completes in console)
    [ValidateSet('Development', 'Staging', 'Production')]
    [string]$Environment,

    # Numeric range
    [ValidateRange(1, 365)]
    [int]$Days,

    # Regex pattern
    [ValidatePattern('^\d{3}-\d{2}-\d{4}$')]
    [string]$Format,

    # Script block — most flexible, custom error message
    [ValidateScript({
        if (Test-Path $_) { return $true }
        throw "Path does not exist: $_"
    })]
    [string]$Path,

    # Not null (allows empty string, unlike ValidateNotNullOrEmpty)
    [ValidateNotNull()]
    [object]$InputObject
)
```

---

## Encoding
```powershell
# PowerShell 5.1 defaults to UTF-16LE — always be explicit
Get-Content  -Path $file -Encoding UTF8
Set-Content  -Path $file -Value $content -Encoding UTF8
Out-File     -FilePath $file -Encoding UTF8
Add-Content  -Path $file -Value $line -Encoding UTF8

# UTF8NoBOM avoids BOM issues when output is consumed on Linux/macOS (PS 6+)
Set-Content  -Path $file -Value $content -Encoding UTF8NoBOM

# Large files — avoid Get-Content, it loads the entire file into memory
[System.IO.File]::ReadLines($path) | Where-Object { $_ -match 'pattern' }
```

---

## Splatting

Use splatting to avoid long lines and to build parameter sets conditionally.
```powershell
# Basic splatting
$params = @{
    Path     = $outputPath
    Value    = $content
    Encoding = 'UTF8'
    Force    = $true
}
Set-Content @params

# Conditional splatting — add parameters only when they have a value
$invokeParams = @{
    Uri    = $uri
    Method = 'GET'
}
if ($Headers)  { $invokeParams['Headers']     = $Headers }
if ($TimeoutSec) { $invokeParams['TimeoutSec'] = $TimeoutSec }

Invoke-RestMethod @invokeParams

# Passing common parameters through to internal calls
function Invoke-Something {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $commonParams = @{}
    if ($VerbosePreference -eq 'Continue') { $commonParams['Verbose'] = $true }
    Invoke-InternalThing @commonParams
}
```

---

## Pipeline Best Practices
```powershell
# Use full cmdlet names in scripts — never aliases
# Aliases differ across platforms and PS versions

# AVOID in scripts
ls | ? { $_.Length -gt 1MB } | % { $_.Name }

# CORRECT
Get-ChildItem | Where-Object { $_.Length -gt 1MB } | ForEach-Object { $_.Name }

# Use -Filter when available — evaluated provider-side, much faster than Where-Object
Get-ChildItem -Path C:\Logs -Filter '*.log' -Recurse
# vs — slow, retrieves all items then filters in PowerShell
Get-ChildItem -Path C:\Logs -Recurse | Where-Object { $_.Extension -eq '.log' }

# Select-Object early to reduce pipeline object size
Get-Process |
    Select-Object Name, CPU, WorkingSet |
    Where-Object { $_.CPU -gt 100 } |
    Sort-Object CPU -Descending
```

---

## Module Management

### PowerShell 5.1 (PowerShellGet v2)
```powershell
# Install from PSGallery
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force

# Find modules
Find-Module -Name '*AD*'
Find-Module -Tag 'Security'

# Update
Update-Module -Name PSScriptAnalyzer

# List installed
Get-InstalledModule

# Require specific module version in a script
#Requires -Modules @{ ModuleName = 'PSScriptAnalyzer'; ModuleVersion = '1.0.0' }
```

### PowerShell 7.4+ (PSResourceGet)
```powershell
# PSResourceGet ships with PS 7.4+ — 2x faster than PowerShellGet
Install-PSResource -Name PSScriptAnalyzer -Scope CurrentUser -TrustRepository
Find-PSResource -Name '*AD*'
Update-PSResource -Name PSScriptAnalyzer
Get-InstalledPSResource

# Install-Module still works in 7.4+ — it calls PSResourceGet internally
```

### Module Import Patterns
```powershell
# Guard import — check before attempting install
if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force
}
Import-Module -Name PSScriptAnalyzer -MinimumVersion 1.0.0

# Pin to exact version
Import-Module -Name PSScriptAnalyzer -RequiredVersion 1.22.0

# Force reload during development
Import-Module -Name MyModule -Force
```

---

## CI/CD Integration

See the Pester skill for full test invocation patterns. The examples below show the
pipeline structure — substitute your own test and lint steps as needed.

### GitHub Actions
```yaml
name: PowerShell CI

on: [push, pull_request]

jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest]
    runs-on: ${{ matrix.os }}

    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        shell: pwsh
        run: |
          Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
          # Add additional module installs here

      - name: Lint
        shell: pwsh
        run: |
          $results = Invoke-ScriptAnalyzer -Path . -Recurse -ReportSummary
          if ($results) { exit 1 }

      - name: Test
        shell: pwsh
        run: |
          # See Pester skill for full configuration options
          Invoke-Pester -Path ./Tests -OutputFormat NUnitXml -OutputFile TestResults.xml

      - name: Publish results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results-${{ matrix.os }}
          path: TestResults.xml
```

### Azure DevOps
```yaml
trigger:
  - main

pool:
  vmImage: windows-latest

steps:
  - task: PowerShell@2
    displayName: Install dependencies
    inputs:
      targetType: inline
      pwsh: true
      script: |
        Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
        # Add additional module installs here

  - task: PowerShell@2
    displayName: Lint
    inputs:
      targetType: inline
      pwsh: true
      script: |
        $results = Invoke-ScriptAnalyzer -Path . -Recurse -ReportSummary
        if ($results) { exit 1 }

  - task: PowerShell@2
    displayName: Test
    inputs:
      targetType: inline
      pwsh: true
      script: |
        # See Pester skill for full configuration options
        Invoke-Pester -Path ./Tests `
          -OutputFormat NUnitXml `
          -OutputFile $(Agent.TempDirectory)/TestResults.xml

  - task: PublishTestResults@2
    displayName: Publish results
    inputs:
      testResultsFormat: NUnit
      testResultsFiles: '$(Agent.TempDirectory)/TestResults.xml'
```

---

## Security

### Credential Handling
```powershell
# NEVER hardcode credentials
# BAD:
$password = 'MyP@ssw0rd'
$cred = New-Object PSCredential('user', (ConvertTo-SecureString 'pass' -AsPlainText -Force))

# GOOD: Interactive prompt
$cred = Get-Credential

# GOOD: SecretManagement module (install from PSGallery)
Install-Module -Name Microsoft.PowerShell.SecretManagement -Scope CurrentUser
$secret = Get-Secret -Name 'DatabasePassword'

# GOOD: Environment variable set outside the script
$token = $env:MY_API_TOKEN
if (-not $token) { throw 'MY_API_TOKEN environment variable is not set' }

# SecureString for sensitive interactive input
$securePass = Read-Host -Prompt 'Password' -AsSecureString
```

### Input Validation

Always validate external input — file paths, API responses, user-supplied values.
```powershell
# Validate file paths before use
if (-not (Test-Path -Path $inputPath -PathType Leaf)) {
    throw "File not found: $inputPath"
}

# Validate expected properties exist on objects
if (-not ($obj.PSObject.Properties.Name -contains 'RequiredProp')) {
    throw "Object missing required property: RequiredProp"
}

# Avoid Invoke-Expression entirely where possible
# If unavoidable, whitelist strictly
$allowedCommands = @('Get-Process', 'Get-Service')
if ($userInput -notin $allowedCommands) {
    throw "Command not allowed: $userInput"
}
```

### Execution Policy
```powershell
# Check all scopes
Get-ExecutionPolicy -List

# Set for current user — no elevation required
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Bypass for a single script run
pwsh -ExecutionPolicy Bypass -File script.ps1

# CI/CD — bypass is acceptable in controlled pipeline environments
```

---

## PSScriptAnalyzer

Run PSScriptAnalyzer on all scripts before committing.
```powershell
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force

# Analyze a single file
Invoke-ScriptAnalyzer -Path .\script.ps1

# Analyze entire directory
Invoke-ScriptAnalyzer -Path . -Recurse -ReportSummary

# Target specific rules
Invoke-ScriptAnalyzer -Path .\script.ps1 `
    -IncludeRule PSAvoidUsingAliases, PSAvoidUsingWriteHost

# Suppress a rule inline — use sparingly, document the reason
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost', '',
    Justification = 'Interactive script — Write-Host is intentional'
)]
param()
```

---

## Common Cmdlets Reference

### File System
```powershell
Get-ChildItem   # List files/directories
Set-Location    # Change directory
New-Item        # Create file or directory
Remove-Item     # Delete
Copy-Item       # Copy
Move-Item       # Move
Rename-Item     # Rename
Get-Content     # Read file
Set-Content     # Write file (replaces content)
Add-Content     # Append to file
Test-Path       # Check existence
Resolve-Path    # Get absolute path
```

### Objects and Pipeline
```powershell
Select-Object   # Choose or compute properties
Where-Object    # Filter objects
ForEach-Object  # Iterate
Sort-Object     # Sort
Group-Object    # Group by property
Measure-Object  # Count/sum/average/min/max
Compare-Object  # Diff two collections
Tee-Object      # Split pipeline to file and stdout
```

### Output
```powershell
Write-Output    # Send object to pipeline (default behavior)
Write-Verbose   # Debug info — visible with -Verbose
Write-Warning   # Yellow warning — always visible
Write-Error     # Red error — non-terminating by default
Write-Host      # Direct to console — avoid in functions, acceptable in scripts
Write-Debug     # Visible with -Debug
```

### Useful Utility Cmdlets
```powershell
Get-Date                          # Current date/time
Measure-Command { ... }           # Time a script block
Start-Sleep -Seconds 5            # Pause execution
Get-Random -Minimum 1 -Maximum 100
ConvertTo-Json    / ConvertFrom-Json
ConvertTo-Csv     / ConvertFrom-Csv
Export-Csv        / Import-Csv
Invoke-RestMethod                 # REST API calls — returns parsed objects
Invoke-WebRequest                 # HTTP requests — returns raw response
```

---

## Pre-Flight Checklist

Before submitting any PowerShell script:

- [ ] `#Requires -Version` set appropriately (5.1 or 7.0)
- [ ] `[CmdletBinding()]` on all functions and scripts
- [ ] `Set-StrictMode -Version Latest` at script top
- [ ] `$ErrorActionPreference = 'Stop'` or `-ErrorAction Stop` on cmdlets in try blocks
- [ ] `try/catch/finally` wrapping all main logic
- [ ] No aliases — full cmdlet names only
- [ ] No array `+=` in loops — use `Generic List[T]`
- [ ] Repeated lookups use a hashtable index, not `Where-Object` in a loop
- [ ] `Join-Path` or `[IO.Path]::Combine()` for all path construction
- [ ] Encoding specified explicitly (critical for 5.1)
- [ ] No hardcoded credentials or tokens
- [ ] `ValidateNotNullOrEmpty` or equivalent on all mandatory parameters
- [ ] PSScriptAnalyzer passes with no errors