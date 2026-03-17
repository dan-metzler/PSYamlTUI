#Requires -Version 5.1
# Import at script level -- this runs during Pester discovery so InModuleScope finds the module.
$script:_repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:_modulePath = Join-Path -Path (Join-Path -Path $script:_repoRoot -ChildPath 'Source') -ChildPath 'PSYamlTUI.psd1'
$global:PSYamlTUI_TestRepoRoot = $script:_repoRoot
Import-Module -Name $script:_modulePath -Force

AfterAll {
    Remove-Module -Name PSYamlTUI -ErrorAction SilentlyContinue
}

InModuleScope PSYamlTUI {

    Describe 'Get-ColorTheme' {

        BeforeAll {
            $requiredKeys = @(
                'Border', 'Title', 'Breadcrumb',
                'ItemDefault', 'ItemSelected', 'ItemHotkey', 'ItemDescription',
                'StatusLabel', 'StatusValue', 'FooterText'
            )
            $themeFixtureDir = Join-Path -Path (Join-Path -Path $global:PSYamlTUI_TestRepoRoot -ChildPath 'Tests\Fixtures') -ChildPath 'themes'
            $partialThemePath = Join-Path -Path $themeFixtureDir -ChildPath 'partial.theme.yaml'
        }

        Context 'Default theme' {

            It 'returns a hashtable with all 10 required keys when Theme is $null' {
                $theme = Get-ColorTheme -Theme $null
                $theme | Should -BeOfType [hashtable]
                $theme.Count | Should -Be 10
                foreach ($key in $requiredKeys) {
                    $theme.ContainsKey($key) | Should -BeTrue -Because "key '$key' is required"
                }
            }

            It 'returns all 10 required keys when called with no arguments' {
                $theme = Get-ColorTheme
                $theme.Count | Should -Be 10
                foreach ($key in $requiredKeys) {
                    $theme.ContainsKey($key) | Should -BeTrue
                }
            }

            It 'returns all 10 required keys when an empty hashtable is passed' {
                $theme = Get-ColorTheme -Theme @{}
                $theme.Count | Should -Be 10
            }

            It 'all non-empty Default theme values are valid ConsoleColor names' {
                $validColors = [System.Enum]::GetNames([System.ConsoleColor])
                $theme = Get-ColorTheme
                foreach ($key in $requiredKeys) {
                    $val = $theme[$key]
                    if (-not [string]::IsNullOrEmpty($val)) {
                        $validColors -contains $val | Should -BeTrue -Because "'$key' = '$val' must be a valid ConsoleColor name"
                    }
                }
            }

            It 'ItemDefault is an empty string in the Default theme' {
                $theme = Get-ColorTheme
                $theme.ItemDefault | Should -Be ''
            }

            It 'Border defaults to DarkCyan' {
                $theme = Get-ColorTheme
                $theme.Border | Should -Be 'DarkCyan'
            }

            It 'ItemSelected defaults to Yellow' {
                $theme = Get-ColorTheme
                $theme.ItemSelected | Should -Be 'Yellow'
            }
        }

        Context 'partial override merges with defaults' {

            It 'single key override replaces only that key and keeps all other defaults' {
                $theme = Get-ColorTheme -Theme @{ Border = 'Blue' }
                $theme.Border        | Should -Be 'Blue'
                $theme.Title         | Should -Be 'White'
                $theme.ItemSelected  | Should -Be 'Yellow'
                $theme.Count         | Should -Be 10
            }

            It 'multiple key override replaces only the specified keys' {
                $theme = Get-ColorTheme -Theme @{ Border = 'DarkBlue'; ItemSelected = 'Green' }
                $theme.Border       | Should -Be 'DarkBlue'
                $theme.ItemSelected | Should -Be 'Green'
                $theme.Title        | Should -Be 'White'
                $theme.Count        | Should -Be 10
            }

            It 'allows ItemDefault to be explicitly set to empty string' {
                $theme = Get-ColorTheme -Theme @{ ItemDefault = '' }
                $theme.ItemDefault | Should -Be ''
            }

            It 'allows StatusValue to be overridden to a different valid color' {
                $theme = Get-ColorTheme -Theme @{ StatusValue = 'Magenta' }
                $theme.StatusValue | Should -Be 'Magenta'
            }
        }

        Context 'full override' {

            It 'all 10 keys provided -- result has no defaults applied' {
                $full = @{
                    Border          = 'Blue'
                    Title           = 'Gray'
                    Breadcrumb      = 'Gray'
                    ItemDefault     = ''
                    ItemSelected    = 'Green'
                    ItemHotkey      = 'Gray'
                    ItemDescription = 'Gray'
                    StatusLabel     = 'Gray'
                    StatusValue     = 'Blue'
                    FooterText      = 'Gray'
                }
                $theme = Get-ColorTheme -Theme $full
                $theme.Border       | Should -Be 'Blue'
                $theme.ItemSelected | Should -Be 'Green'
                $theme.Count        | Should -Be 10
            }
        }

        Context 'validation errors' {

            It 'throws for an unknown theme key' {
                { Get-ColorTheme -Theme @{ UnknownKey = 'Cyan' } } |
                Should -Throw
            }

            It 'error message for unknown key includes the unrecognized key name' {
                try {
                    Get-ColorTheme -Theme @{ InvalidKeyName = 'Cyan' }
                }
                catch {
                    $_.Exception.Message | Should -Match 'InvalidKeyName'
                }
            }

            It 'throws for an invalid ConsoleColor value' {
                { Get-ColorTheme -Theme @{ Border = 'NotAValidColor' } } |
                Should -Throw
            }

            It 'error message for invalid color includes both the key and the invalid value' {
                try {
                    Get-ColorTheme -Theme @{ Border = 'PurpleGreen' }
                }
                catch {
                    $_.Exception.Message | Should -Match 'Border'
                    $_.Exception.Message | Should -Match 'PurpleGreen'
                }
            }

            It 'accepts all valid ConsoleColor names without throwing' {
                $validColors = [System.Enum]::GetNames([System.ConsoleColor])
                # Pick a random valid color -- just verify no throw
                { Get-ColorTheme -Theme @{ Border = $validColors[0] } } |
                Should -Not -Throw
            }
        }

        Context 'theme file loading' {

            It 'loads a flat YAML theme file path' {
                $theme = Get-ColorTheme -ThemePath $partialThemePath
                $theme.Border | Should -Be 'Blue'
                $theme.Title | Should -Be 'White'
                $theme.ItemSelected | Should -Be 'Yellow'
                $theme.Count | Should -Be 10
            }

            It 'loads a YAML theme file with a top-level theme mapping' {
                $themePath = Join-Path -Path $TestDrive -ChildPath 'wrapped.theme.yaml'
                @'
theme:
  Border: "DarkBlue"
  StatusValue: "Green"
'@ | Set-Content -Path $themePath -Encoding UTF8

                $theme = Get-ColorTheme -ThemePath $themePath
                $theme.Border | Should -Be 'DarkBlue'
                $theme.StatusValue | Should -Be 'Green'
                $theme.Title | Should -Be 'White'
                $theme.Count | Should -Be 10
            }

            It 'loads a JSON theme file path' {
                $themePath = Join-Path -Path $TestDrive -ChildPath 'custom.theme.json'
                @'
{
  "Border": "DarkGreen",
  "ItemSelected": "Cyan"
}
'@ | Set-Content -Path $themePath -Encoding UTF8

                $theme = Get-ColorTheme -ThemePath $themePath
                $theme.Border | Should -Be 'DarkGreen'
                $theme.ItemSelected | Should -Be 'Cyan'
                $theme.Title | Should -Be 'White'
                $theme.Count | Should -Be 10
            }

            It 'throws when the theme file does not exist' {
                $missingPath = Join-Path -Path $TestDrive -ChildPath 'missing.theme.yaml'
                { Get-ColorTheme -ThemePath $missingPath } | Should -Throw
            }

            It 'error message for missing theme file includes the path' {
                $missingPath = Join-Path -Path $TestDrive -ChildPath 'missing.theme.yaml'
                try {
                    Get-ColorTheme -ThemePath $missingPath
                }
                catch {
                    $_.Exception.Message | Should -Match 'Theme file not found'
                    $_.Exception.Message | Should -Match 'missing.theme.yaml'
                }
            }

            It 'throws when the file extension is unsupported' {
                $themePath = Join-Path -Path $TestDrive -ChildPath 'custom.theme.txt'
                'Border: "Blue"' | Set-Content -Path $themePath -Encoding UTF8
                { Get-ColorTheme -ThemePath $themePath } | Should -Throw
            }

            It 'throws when a YAML theme file cannot be parsed' {
                $themePath = Join-Path -Path $TestDrive -ChildPath 'broken.theme.yaml'
                @'
theme:
    Border: "Blue"
    Title: [
'@ | Set-Content -Path $themePath -Encoding UTF8
                { Get-ColorTheme -ThemePath $themePath } | Should -Throw
            }

            It 'throws when a JSON theme file cannot be parsed' {
                $themePath = Join-Path -Path $TestDrive -ChildPath 'broken.theme.json'
                '{ "Border": "Blue", ' | Set-Content -Path $themePath -Encoding UTF8
                { Get-ColorTheme -ThemePath $themePath } | Should -Throw
            }

            It 'throws when theme root is not a mapping' {
                $themePath = Join-Path -Path $TestDrive -ChildPath 'list.theme.yaml'
                @'
- "Blue"
'@ | Set-Content -Path $themePath -Encoding UTF8

                { Get-ColorTheme -ThemePath $themePath } | Should -Throw
            }

            It 'throws when top-level theme key is not a mapping' {
                $themePath = Join-Path -Path $TestDrive -ChildPath 'bad-wrapped.theme.yaml'
                @'
theme: "Blue"
'@ | Set-Content -Path $themePath -Encoding UTF8

                { Get-ColorTheme -ThemePath $themePath } | Should -Throw
            }

            It 'throws when a theme file contains an invalid color value' {
                $themePath = Join-Path -Path $TestDrive -ChildPath 'invalid-color.theme.yaml'
                @'
Border: "PurpleGreen"
'@ | Set-Content -Path $themePath -Encoding UTF8

                { Get-ColorTheme -ThemePath $themePath } | Should -Throw
            }

            It 'throws when a theme file contains a nested object for a color key' {
                $themePath = Join-Path -Path $TestDrive -ChildPath 'nested.theme.yaml'
                @'
Border:
  Name: "Blue"
'@ | Set-Content -Path $themePath -Encoding UTF8

                { Get-ColorTheme -ThemePath $themePath } | Should -Throw
            }

            It 'throws when Theme and ThemePath are passed together' {
                { Get-ColorTheme -Theme @{ Border = 'Blue' } -ThemePath $partialThemePath } | Should -Throw
            }
        }
    }
}
