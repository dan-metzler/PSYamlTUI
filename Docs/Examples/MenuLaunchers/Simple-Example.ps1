$here = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$repoRoot = Join-Path (Join-Path (Join-Path $here '..') '..') '..'
$moduleManifest = Join-Path -Path $repoRoot -ChildPath 'Source\PSYamlTUI.psd1'
$fixturesRoot = Join-Path (Join-Path $here '..') 'Fixtures'
$menuPath = Join-Path -Path $fixturesRoot -ChildPath 'menus\simple.menu.yaml'
$themePath = Join-Path -Path $fixturesRoot -ChildPath 'themes\simple.theme.yaml'

Import-Module -Name $moduleManifest -Force

Start-Menu -Path $menuPath -ThemePath $themePath -BorderStyle Single
