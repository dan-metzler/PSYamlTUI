# -- Load bundled YamlDotNet for YAML parsing ----------------------------------
$_libPath = Join-Path (Join-Path $PSScriptRoot 'lib') 'YamlDotNet.dll'
if (Test-Path -LiteralPath $_libPath) {
    # Check AppDomain before calling Add-Type — it throws a terminating error
    # (not catchable by -ErrorAction) if the assembly is already loaded in the session.
    $_loaded = [System.AppDomain]::CurrentDomain.GetAssemblies() |
    Where-Object { $_.GetName().Name -eq 'YamlDotNet' }
    if (-not $_loaded) {
        Add-Type -Path $_libPath
    }
}
else {
    Write-Warning "PSYamlTUI: YamlDotNet.dll not found at '$_libPath'. Download it and place it in the lib/ folder. See README for instructions."
}

# -- Development dot-sourcing ---------------------------------------------------
# ModuleBuilder inlines these files into the compiled output.
# When running from Source/ directly (uncompiled), they are dot-sourced here.
Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue |
ForEach-Object { . $_.FullName }

Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue |
ForEach-Object { . $_.FullName }

# -- Module-scoped state (initialized per Start-Menu call) ---------------------
$script:YamlTUI_TermProfile = $null
$script:YamlTUI_CharSet = $null
$script:YamlTUI_Quit = $false
$script:YamlTUI_Home = $false
$script:YamlTUI_ImportCache = @{}

