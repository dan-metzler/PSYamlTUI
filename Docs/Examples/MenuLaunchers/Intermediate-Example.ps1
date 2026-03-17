$here = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$repoRoot = Join-Path (Join-Path (Join-Path $here '..') '..') '..'
$moduleManifest = Join-Path -Path $repoRoot -ChildPath 'Source\PSYamlTUI.psd1'
$fixturesRoot = Join-Path (Join-Path $here '..') 'Fixtures'
$menuPath = Join-Path -Path $fixturesRoot -ChildPath 'menus\intermediate.menu.yaml'
$themePath = Join-Path -Path $fixturesRoot -ChildPath 'themes\intermediate.theme.json'

Import-Module -Name $moduleManifest -Force

$identityName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$currentUser = ($identityName -split '\\')[-1]

$statusData = @{
    'Connected As' = $currentUser
    'Environment'  = 'Production'
}

$themeObject = Get-Content -Path $themePath -Raw | ConvertFrom-Json
$theme = @{}
$themeObject.PSObject.Properties | ForEach-Object {
    $theme[$_.Name] = [string]$_.Value
}

Start-Menu -Path $menuPath -StatusData $statusData -Theme $theme -BorderStyle Rounded
