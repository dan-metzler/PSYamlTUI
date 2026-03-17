[CmdletBinding()]
param(
    # Parameter help description
    [Parameter(Mandatory)]
    [ValidateSet("Local", "Full")]
    [string]$Type,

    [Parameter()]
    [string]$Version = $(
        $tag = git describe --tags --abbrev=0 2>$null
        if ($tag) { $tag.TrimStart('v') } else { '0.1.0' }
    )
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
#Requires -Module InvokeBuild

Import-Module InvokeBuild
. "$PSScriptRoot\Build\BuildFunctions.ps1"

# ============================================================================
# Script-Scoped Variables
# ============================================================================
# Shared across all tasks to avoid redundant module discovery and imports.
# Populated by the ModuleImport task and consumed by downstream tasks.

$script:moduleName = $null

# ============================================================================
# Define Build Tasks
# ============================================================================
task CheckGitStatus {
    Test-GitStatus -ExpectedBranch 'main' 
}

task BuildModule {
    $ok = & "$PSScriptRoot\Source\ModuleBuilder.ps1" -Version $Version
    if (-Not($ok)) { throw "ModuleBuilder.ps1 failed" }
}

# ============================================================================
# Task: CopyLibFiles
# ============================================================================
# ModuleBuilder only inlines .ps1 files - it does not copy bundled binaries.
# This task copies Source/lib/ (YamlDotNet.dll etc.) into the built output
# so the compiled module can load its dependencies at runtime.

task CopyLibFiles BuildModule, {
    $srcLib = Join-Path (Join-Path $PSScriptRoot 'Source') 'lib'
    $outDir = Get-ChildItem -Path "$PSScriptRoot\Output" -Filter '*.psd1' -Recurse |
    Select-Object -First 1 | ForEach-Object { $_.DirectoryName }

    if (-not $outDir) { throw "CopyLibFiles: could not locate Output module directory." }

    $destLib = Join-Path $outDir 'lib'

    if (Test-Path -LiteralPath $srcLib) {
        $null = New-Item -ItemType Directory -Path $destLib -Force
        Copy-Item -Path "$srcLib\*" -Destination $destLib -Recurse -Force
        Write-Verbose "Copied lib/ to $destLib" -Verbose
    }
    else {
        Write-Warning "CopyLibFiles: Source\lib\ not found — skipping. Run Install-Requirements.ps1 first."
    }

    # ModuleBuilder replaces the entire psm1 with inlined functions, discarding
    # the DLL loader from Source/PSYamlTUI.psm1. Prepend an AppDomain-guard
    # loader so the assembly is loaded on first import and silently skipped on
    # subsequent Import-Module -Force calls in the same session.
    $moduleName = Split-Path $outDir -Leaf
    $compiledPsm1 = Join-Path $outDir "$moduleName.psm1"
    if (Test-Path -LiteralPath $compiledPsm1) {
        $loader = @'
# -- Load bundled YamlDotNet (injected by build pipeline) --------------------
$_yt_lib = Join-Path $PSScriptRoot (Join-Path 'lib' 'YamlDotNet.dll')
if (Test-Path -LiteralPath $_yt_lib) {
    $_yt_loaded = [System.AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object { $_.GetName().Name -eq 'YamlDotNet' }
    if (-not $_yt_loaded) { Add-Type -Path $_yt_lib }
}
# ---------------------------------------------------------------------------

'@
        $existing = Get-Content -Path $compiledPsm1 -Raw
        Set-Content -Path $compiledPsm1 -Value ($loader + $existing) -Encoding UTF8
        Write-Verbose "Injected YamlDotNet loader into compiled psm1" -Verbose
    }
}

# ============================================================================
# Task: ModuleImport
# ============================================================================
# Validates and imports the compiled module into the current session.
# Populates the script-scoped $moduleName variable for use by
# downstream tasks (e.g., GenerateMarkdownDocs, RunTests).
#
# Validations performed:
#   - Module manifest (.psd1) exists in the Output directory
#   - Module name is defined and non-empty in the manifest

task ModuleImport BuildModule, CopyLibFiles, {
    $getPsdFile = Get-ChildItem -Path "$PSScriptRoot\Output\*.psd1" -Recurse | Select-Object -First 1

    if (-not $getPsdFile) {
        throw "No .psd1 file found in the Output directory."
    }

    $script:moduleName = [System.IO.Path]::GetFileNameWithoutExtension($getPsdFile.Name)

    if ([string]::IsNullOrEmpty($script:moduleName)) {
        throw "Module name is missing in the .psd1 file."
    }

    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
    Import-Module -Name $getPsdFile.FullName -Force -ErrorAction Stop
    Write-Verbose "Imported module: $script:moduleName" -Verbose
}

# ============================================================================
# Task: GenerateMarkdownDocs
# ============================================================================
# Generates markdown documentation for all exported module functions using platyPS.
# Depends on ModuleImport to ensure $moduleName is populated.
# Creates function reference documentation in the Docs directory.

task GenerateMarkdownDocs ModuleImport, {
    Import-Module platyPS -ErrorAction Stop
    Write-Verbose "Generating Function Markdown Documentation..."

    $docsPath = "$PSScriptRoot\Docs"
    if (-Not(Test-Path -Path $docsPath -PathType Container)) {
        throw "Could not find the Docs directory at $docsPath. Confirm the directory exists and try again."
    }

    if (New-MarkdownHelp -Module $script:moduleName -OutputFolder $docsPath -Force) {
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

task RunTests ModuleImport, {
    Import-Module Pester -ErrorAction Stop

    $config = New-PesterConfiguration
    $config.Run.Path = "$PSScriptRoot\Tests"
    $config.Run.Exit = $true
    $config.Output.Verbosity = 'Detailed'

    Invoke-Pester -Configuration $config
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
#   3. CopyLibFiles          - Copy required library files to the output directory
#   4. ModuleImport          - Validate and import module artifact
#   5. GenerateMarkdownDocs  - Create function documentation (depends on ModuleImport)
#   6. RunTests              - Verify module functionality via Pester

switch ($Type) {
    "Local" {
        Write-Verbose "Executing local build pipeline..." -Verbose
        task . BuildModule, ModuleImport, CopyLibFiles
    }
    "Full" {
        Write-Verbose "Executing full build pipeline..." -Verbose
        task . BuildModule, CopyLibFiles, ModuleImport, RunTests

    }
    default {
        throw "Invalid build type specified. Use 'Local' or 'Full'."
    }
}