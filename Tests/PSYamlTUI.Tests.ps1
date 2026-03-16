#Requires -Version 5.1
<#
.SYNOPSIS
    PSYamlTUI test suite entry point.
.DESCRIPTION
    Discovers and runs all tests under the Tests/ directory.
    Run directly with Pester or use the helper commands below.

.EXAMPLE
    # Run all tests with detailed output
    Invoke-Pester -Path .\Tests\ -Output Detailed

.EXAMPLE
    # Run using this entry point
    Invoke-Pester -Path .\Tests\PSYamlTUI.Tests.ps1

.EXAMPLE
    # Run with coverage report
    $cfg = New-PesterConfiguration
    $cfg.Run.Path          = '.\Tests\'
    $cfg.Output.Verbosity  = 'Detailed'
    $cfg.CodeCoverage.Enabled = $true
    $cfg.CodeCoverage.Path = '.\Source\Private\*.ps1', '.\Source\Public\*.ps1'
    Invoke-Pester -Configuration $cfg

.NOTES
    Requires Pester 5.x  -- Install-Module Pester -MinimumVersion 5.0 -Force
    YamlDotNet.dll must be present in Source/lib/ -- run .\Install-Requirements.ps1
#>
param()

$config = New-PesterConfiguration
$config.Run.Path = Join-Path -Path $PSScriptRoot -ChildPath 'Unit'
$config.Output.Verbosity = 'Detailed'

# Include integration tests
$config.Run.Path = @(
    (Join-Path -Path $PSScriptRoot -ChildPath 'Unit'),
    (Join-Path -Path $PSScriptRoot -ChildPath 'Integration')
)

Invoke-Pester -Configuration $config
