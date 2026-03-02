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
# Module Imports and Dependencies
# ============================================================================
# InvokeBuild: Task-based build framework enabling declarative build pipelines
# BuildFunctions.ps1: Custom utilities for Git validation and module operations

Import-Module InvokeBuild
. "$PSScriptRoot\Build\BuildFunctions.ps1"

# ============================================================================
# Task: CheckGitStatus
# ============================================================================
# Validates that the build is being executed from the 'main' git branch.
# This prevents accidental builds from feature or development branches and
# ensures builds are only created from the stable, integration branch.

task CheckGitStatus {
    Test-GitStatus -ExpectedBranch 'main' 
}

# ============================================================================
# Task: BuildModule
# ============================================================================
# Invokes the ModuleBuilder script to compile, package, and version the module.
# ModuleBuilder.ps1 handles manifest discovery, metadata validation, and
# invokes the ModuleBuilder framework to generate the output artifact.
# Throws exception on failure to halt the pipeline.

task BuildModule {
    $ok = & "$PSScriptRoot\Source\ModuleBuilder.ps1"
    if (-Not($ok)) { throw "ModuleBuilder.ps1 failed" }
}

# ============================================================================
# Task: ModuleImport
# ============================================================================
# Validates and imports the compiled module into the current session.
# This runtime validation ensures the module artifact is properly structured
# with valid metadata before proceeding to testing.
#
# Validations performed:
#   - Module manifest (.psd1) exists in the Output directory
#   - Module name is defined and non-empty in the manifest

task ModuleImport {

    $getPsdFile = Get-ChildItem -Path "$PSScriptRoot\Output\*.psd1" -Recurse | Select-Object -First 1

    if (-not($getPsdFile)) {
        throw "No .psd1 file found in the Output directory."
    }
    
    $moduleDetails = $getPsdFile | Import-Module -PassThru -Force

    if ([string]::IsNullOrEmpty($moduleDetails.Name)) {
        throw "Module name is missing in the .psd1 file. Confirm .psd1 file configuration."
    }

}

# ============================================================================
# Task: RunTests
# ============================================================================
# Executes all Pester test suites against the compiled module.
# Discovers and runs all .Tests.ps1 files in the Tests directory.
# Validates module functionality, command exports, and parameter sets.
# Build fails if any test fails.

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
#   1. CheckGitStatus   - Ensure build branch is 'main'
#   2. BuildModule      - Compile and package the module
#   3. ModuleImport     - Validate module artifact integrity
#   4. RunTests         - Verify module functionality via Pester

task . CheckGitStatus, BuildModule, ModuleImport, RunTests