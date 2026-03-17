$here = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$repoRoot = Join-Path (Join-Path (Join-Path $here '..') '..') '..'
$moduleManifest = Join-Path -Path $repoRoot -ChildPath 'Source\PSYamlTUI.psd1'
$fixturesRoot = Join-Path (Join-Path $here '..') 'Fixtures'
$menuPath = Join-Path -Path $fixturesRoot -ChildPath 'menus\intermediate.menu.yaml'
$themePath = Join-Path -Path $fixturesRoot -ChildPath 'themes\intermediate.theme.yaml'

Import-Module -Name $moduleManifest -Force

$identityName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$currentUser = ($identityName -split '\\')[-1]

$statusData = @{
    'Connected As' = $currentUser
    'Environment'  = 'Production'
    'Region'       = 'us-east-1'
}

# Arrow keys: Left = Back one level, Right = Enter/Select
$keyBindings = @{
    Up     = [System.ConsoleKey]::UpArrow
    Down   = [System.ConsoleKey]::DownArrow
    Select = @([System.ConsoleKey]::Enter, [System.ConsoleKey]::RightArrow)
    Back   = @([System.ConsoleKey]::Escape, [System.ConsoleKey]::LeftArrow)
    Quit   = 'Q'
    Home   = 'H'
}

Start-Menu -Path $menuPath -StatusData $statusData -ThemePath $themePath -BorderStyle Rounded `
    -KeyBindings $keyBindings -Context @{ currentUser = $currentUser }
