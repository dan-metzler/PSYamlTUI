param(
    [version]$Version = "1.0.0"
)
#Requires -Module ModuleBuilder

$params = @{
    SourcePath = "$PSScriptRoot"  # points to folder with NewModule.psd1 & NewModule.psm1
    Version = $Version
    UnversionedOutputDirectory = $true
}

$success = $false
try {
    Build-Module @params
    $success = Test-Path "$PSScriptRoot\..\Output\NewModule\NewModule.psd1"
} catch {
    Write-Error $_
}

return $success