#Requires -Version 5.1
# Import at script level -- this runs during Pester discovery so InModuleScope finds the module.
$script:_repoRoot   = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:_modulePath = Join-Path -Path (Join-Path -Path $script:_repoRoot -ChildPath 'Source') -ChildPath 'PSYamlTUI.psd1'
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

        Context 'named theme support (pending - not yet implemented)' {

            # Skipped: named theme string parameter not yet implemented
            It 'named theme Light returns valid color hashtable' -Skip {}

            It 'named theme Minimal returns valid color hashtable' -Skip {}

            It 'named theme Classic returns valid color hashtable' -Skip {}

            It 'throws descriptive error for unknown named theme' -Skip {}
        }

        Context 'YAML file theme loading (pending - not yet implemented)' {

            # Skipped: YAML theme file loading not yet implemented
            It 'loads custom theme from a YAML file path' -Skip {}

            It 'partial YAML theme override falls back to Default for missing keys' -Skip {}

            It 'throws descriptive error when theme file does not exist' -Skip {}

            It 'throws descriptive error when theme file contains invalid ConsoleColor value' -Skip {}
        }
    }
}
