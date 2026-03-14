[CmdletBinding()]
param(
    # Parameter help description
    [Parameter(Mandatory)]
    [ValidateSet("Local", "Full")]
    [string]$Type
)

<#
.SYNOPSIS
    Build orchestration script using InvokeBuild framework.

.DESCRIPTION
    This script defines the complete build pipeline for the PowerShell module project.
    It coordinates multiple build tasks: Git status validation, module compilation,
    module import verification, and automated testing via Pester.

.NOTES
    - Requires InvokeBuild module (dependency management for task-based builds)
    - Builds are restricted to the 'main' git branch
    - Returns exit code 0 on success; non-zero on task failures
#>

# ============================================================================
# Import Dependencies and Build Functions
# ============================================================================
#Requires -Module ModuleBuilder
#Requires -Module Pester
#Requires -Module InvokeBuild
#Requires -Module platyPS

Import-Module InvokeBuild
. "$PSScriptRoot\Build\BuildFunctions.ps1"

# ============================================================================
# Script-Scoped Variables
# ============================================================================
# Shared across all tasks to avoid redundant module discovery and imports.
# Populated by the ModuleImport task and consumed by downstream tasks.

$script:ModuleDetails = $null

# ============================================================================
# Define Build Tasks
# ============================================================================
task CheckGitStatus {
    Test-GitStatus -ExpectedBranch 'main' 
}

task BuildModule {
    $ok = & "$PSScriptRoot\Source\ModuleBuilder.ps1"
    if (-Not($ok)) { throw "ModuleBuilder.ps1 failed" }
}

# ============================================================================
# Task: ModuleImport
# ============================================================================
# Validates and imports the compiled module into the current session.
# Populates the script-scoped $script:ModuleDetails variable for use by
# downstream tasks (e.g., GenerateMarkdownDocs, RunTests).
#
# Validations performed:
#   - Module manifest (.psd1) exists in the Output directory
#   - Module name is defined and non-empty in the manifest

task ModuleImport BuildModule, {
    $getPsdFile = Get-ChildItem -Path "$PSScriptRoot\Output\*.psd1" -Recurse | Select-Object -First 1
    
    if (-not($getPsdFile)) {
        throw "No .psd1 file found in the Output directory."
    }

    $script:ModuleDetails = $getPsdFile | Import-Module -PassThru -Force

    if ([string]::IsNullOrEmpty($script:ModuleDetails.Name)) {
        throw "Module name is missing in the .psd1 file. Confirm .psd1 file configuration."
    }
}

# ============================================================================
# Task: GenerateMarkdownDocs
# ============================================================================
# Generates markdown documentation for all exported module functions using platyPS.
# Depends on ModuleImport to ensure $script:ModuleDetails is populated.
# Creates function reference documentation in the Docs directory.

task GenerateMarkdownDocs ModuleImport, {
    Write-Verbose "Generating Function Markdown Documentation..." -Verbose

    $docsPath = "$PSScriptRoot\Docs"
    if (-Not(Test-Path -Path $docsPath -PathType Container)) {
        throw "Could not find the Docs directory at $docsPath. Confirm the directory exists and try again."
    }

    if (New-MarkdownHelp -Module $script:ModuleDetails.Name -OutputFolder $docsPath -Force) {
        Write-Verbose "Done." -Verbose
    }
    else {
        throw $_.Exception.Message
    }
}

# ============================================================================
# Task: RunTests
# ============================================================================
# Executes all Pester test suites against the compiled module.
# Discovers and runs all .Tests.ps1 files in the Tests directory.
# Validates module functionality, command exports, and parameter sets.

task RunTests {
    Invoke-Pester -Script "$PSScriptRoot\Tests"
}


# ============================================================================
# Default Build Pipeline
# ============================================================================
# Defines the complete build orchestration sequence.
# Tasks execute in order; failure at any stage halts the pipeline.
#
# Execution sequence:
#   1. CheckGitStatus        - Ensure build branch is 'main'
#   2. BuildModule           - Compile and package the module
#   3. ModuleImport          - Validate and import module artifact
#   4. GenerateMarkdownDocs  - Create function documentation (depends on ModuleImport)
#   5. RunTests              - Verify module functionality via Pester

$buildType = switch ($Type) {
    "Local" {
        Write-Verbose "Executing local build pipeline..." -Verbose
        Invoke-Build -Task BuildModule, ModuleImport
    }
    "Full" {
        Write-Verbose "Executing full build pipeline..." -Verbose
        Invoke-Build -Task CheckGitStatus, BuildModule, ModuleImport, GenerateMarkdownDocs, RunTests
    }
    default {
        throw "Invalid build type specified. Use 'Local' or 'Full'."
    }
}

task . $buildType