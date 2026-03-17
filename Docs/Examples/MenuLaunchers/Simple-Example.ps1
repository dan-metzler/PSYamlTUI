$here = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$repoRoot = Join-Path (Join-Path (Join-Path $here '..') '..') '..'
$moduleManifest = Join-Path -Path $repoRoot -ChildPath 'Source\PSYamlTUI.psd1'
$fixturesRoot = Join-Path (Join-Path $here '..') 'Fixtures'
$menuPath = Join-Path -Path $fixturesRoot -ChildPath 'menus\simple.menu.yaml'
$themePath = Join-Path -Path $fixturesRoot -ChildPath 'themes\simple.theme.json'

Import-Module -Name $moduleManifest -Force

$themeObject = Get-Content -Path $themePath -Raw | ConvertFrom-Json
$theme = @{}
$themeObject.PSObject.Properties | ForEach-Object {
    $theme[$_.Name] = [string]$_.Value
}

Start-Menu -Path $menuPath -Theme $theme -BorderStyle Single
