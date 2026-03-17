$here = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$repoRoot = Join-Path (Join-Path (Join-Path $here '..') '..') '..'
$moduleManifest = Join-Path -Path $repoRoot -ChildPath 'Source\PSYamlTUI.psd1'
$fixturesRoot = Join-Path (Join-Path $here '..') 'Fixtures'
$menuPath = Join-Path -Path $fixturesRoot -ChildPath 'menus\advanced.menu.yaml'
$varsPath = Join-Path -Path $fixturesRoot -ChildPath 'vars\advanced.var.yaml'
$themePath = Join-Path -Path $fixturesRoot -ChildPath 'themes\advanced.theme.json'
$hooksPath = Join-Path (Join-Path $here '..') 'Scripts\Register-ExampleHooks.ps1'

Import-Module -Name $moduleManifest -Force
. $hooksPath

$identityName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$currentUser = ($identityName -split '\\')[-1]

$statusData = @{
    'Connected As' = $currentUser
    'Environment'  = 'Production'
    'Region'       = 'us-east-1'
}

$themeObject = Get-Content -Path $themePath -Raw | ConvertFrom-Json
$theme = @{}
$themeObject.PSObject.Properties | ForEach-Object {
    $theme[$_.Name] = [string]$_.Value
}

$keyBindings = @{
    Up     = [System.ConsoleKey]::UpArrow
    Down   = [System.ConsoleKey]::DownArrow
    Select = [System.ConsoleKey]::RightArrow
    Back   = [System.ConsoleKey]::LeftArrow
    Quit   = 'X'
    Home   = 'H'
}

$context = @{
    currentUser = $currentUser
}

try {
    Start-Menu -Path $menuPath -VarsPath $varsPath -Context $context -StatusData $statusData -Theme $theme -BorderStyle Rounded -KeyBindings $keyBindings -Timer
}
finally {
    if (Get-Command -Name 'Unregister-ExampleHooks' -CommandType Function -ErrorAction SilentlyContinue) {
        Unregister-ExampleHooks
    }
}
