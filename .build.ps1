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
# Module Manifest Discovery & Validation
# ============================================================================

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

task GenerateMarkdownDocs {
    Write-Verbose "Generating Function Markdown Documentation..." -Verbose

    $docsPath = "$PSScriptRoot\Docs"
    if (-Not(Test-Path -Path $docsPath -PathType Container)) {
        throw "Could not find the Docs directory at $docsPath. Confirm the directory exists and try again."
    }

    if (New-MarkdownHelp -Module $moduleDetails.Name -OutputFolder $docsPath -Force) {
        Write-Verbose "Done." -Verbose
    }
    else {
        throw $_.Exception.Message
    }
}

task RunTests {
    Invoke-Pester -Script "$PSScriptRoot\Tests"
}


# ============================================================================
# Execute Build Pipeline
# ============================================================================
task . CheckGitStatus, BuildModule, ModuleImport, GenerateMarkdownDocs, RunTests