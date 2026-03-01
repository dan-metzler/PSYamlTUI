[CmdletBinding()]
param(
    [version]$Version = "1.0.0"
)
#Requires -Module ModuleBuilder

$moduleDetails = Import-Module "$PSScriptRoot\..\Source\NewModule.psd1" -PassThru

if([string]::IsNullOrEmpty($moduleDetails.Name)) {
    throw "Module name is missing in the .psd1 file."
}

$params = @{
    SourcePath = "$PSScriptRoot"  # points to folder with NewModule.psd1 & NewModule.psm1
    OutputDirectory = "$PSScriptRoot\..\Output\NewModule"
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