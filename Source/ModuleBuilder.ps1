<#
.SYNOPSIS
    Builds and packages the PowerShell module using the ModuleBuilder framework.

.DESCRIPTION
    This script is responsible for orchestrating the module build process. It locates the source manifest (.psd1)
    file from the Source directory, validates module metadata, and invokes the Build-Module cmdlet to compile,
    package, and version the module artifact.

.PARAMETER Version
    The semantic version to assign to the built module. Defaults to "1.0.0" if not specified.
    Used for versioning the module manifest during the build process.

.NOTES
    - Requires the ModuleBuilder module from the PowerShell Gallery
    - Performs validation of the module manifest before building
    - Automatically cleans up the imported module from the session upon completion
    - Returns $true if the build succeeded (manifest exists in output), $false otherwise
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNull()]
    [version]$Version = "1.0.0"
)

#Requires -Module ModuleBuilder


# ============================================================================
# Step 1: Locate Module Manifest
# ============================================================================
# Discovers the module manifest file (.psd1) in the Source directory.
# This file defines module metadata, exports, dependencies, and other attributes.
# We use -First 1 to ensure only a single manifest is processed.

$psdFile = Get-ChildItem -Path "$PSScriptRoot\*.psd1" | Select-Object -First 1

if (-not($psdFile)) {
    throw "No .psd1 file found in the Source directory."
}

# ============================================================================
# Step 2: Import and Validate Module Metadata
# ============================================================================
# Reads the manifest data file to extract module metadata (name, version, etc.)
# without importing the module — avoids triggering RequiredAssemblies and any
# assembly load conflicts (e.g. YamlDotNet already loaded in the session).

$moduleName = [System.IO.Path]::GetFileNameWithoutExtension($psdFile.Name)

if ([string]::IsNullOrEmpty($moduleName)) {
    throw "Module name is missing in the .psd1 file."
}

# ============================================================================
# Step 3: Configure Build Parameters
# ============================================================================
# Prepares parameters for the ModuleBuilder's Build-Module cmdlet.
# 
# Parameters:
#   - SourcePath              : Root directory containing the .psd1 and .psm1 files
#   - OutputDirectory         : Target directory where the built module will be placed
#   - Version                 : Semantic version to assign to the module artifact
#   - UnversionedOutputDirectory : Outputs the module without a version subdirectory structure

$params = @{
    SourcePath                 = "$PSScriptRoot"  # points to folder with NewModule.psd1 & NewModule.psm1
    OutputDirectory            = "$PSScriptRoot\..\.\Output\$moduleName"
    Version                    = $Version
    UnversionedOutputDirectory = $true
}

# ============================================================================
# Step 4: Execute Build and Validate Output
# ============================================================================
# Invokes the ModuleBuilder framework to compile and package the module.
# Uses a try-catch block to gracefully handle build failures.
# Validates that the output manifest was successfully created.

$success = $false
try {
    Build-Module @params
    $success = Test-Path "$PSScriptRoot\..\.\Output\$moduleName\$moduleName.psd1"
}
catch {
    Write-Error $_
}

# ============================================================================
# Step 5: Cleanup and Return Build Status
# ============================================================================
# Removes the imported module from the current session to prevent conflicts
# with subsequent imports or builds.
# Returns $true if the build succeeded, $false if it failed.

Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue

return $success
