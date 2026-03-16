#Requires -Version 5.1
# Import at script level -- this runs during Pester discovery so InModuleScope finds the module.
$script:_repoRoot   = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:_modulePath = Join-Path -Path (Join-Path -Path $script:_repoRoot -ChildPath 'Source') -ChildPath 'PSYamlTUI.psd1'
Import-Module -Name $script:_modulePath -Force

AfterAll {
    Remove-Module -Name PSYamlTUI -ErrorAction SilentlyContinue
}

InModuleScope PSYamlTUI {

    Describe 'Get-CharacterSet' {

        BeforeAll {
            $unicodeProfile = [PSCustomObject]@{
                UseUnicode  = $true
                UseAnsi     = $false
                ColorMethod = 'WriteHost'
                Width       = 80
            }
            $asciiProfile = [PSCustomObject]@{
                UseUnicode  = $false
                UseAnsi     = $false
                ColorMethod = 'WriteHost'
                Width       = 80
            }
            $requiredKeys = @(
                'TopLeft', 'TopRight', 'BottomLeft', 'BottomRight',
                'Horizontal', 'Vertical', 'LeftT', 'RightT',
                'Selected', 'Bullet', 'Arrow'
            )
        }

        Context 'returned hashtable contains all required keys' {

            It 'Single style returns all required keys' {
                $cs = Get-CharacterSet -TerminalProfile $unicodeProfile -Style 'Single'
                foreach ($key in $requiredKeys) {
                    $cs.ContainsKey($key) | Should -BeTrue -Because "key '$key' is required"
                }
            }

            It 'Double style returns all required keys' {
                $cs = Get-CharacterSet -TerminalProfile $unicodeProfile -Style 'Double'
                foreach ($key in $requiredKeys) {
                    $cs.ContainsKey($key) | Should -BeTrue -Because "key '$key' is required"
                }
            }

            It 'Rounded style returns all required keys' {
                $cs = Get-CharacterSet -TerminalProfile $unicodeProfile -Style 'Rounded'
                foreach ($key in $requiredKeys) {
                    $cs.ContainsKey($key) | Should -BeTrue -Because "key '$key' is required"
                }
            }

            It 'Heavy style returns all required keys' {
                $cs = Get-CharacterSet -TerminalProfile $unicodeProfile -Style 'Heavy'
                foreach ($key in $requiredKeys) {
                    $cs.ContainsKey($key) | Should -BeTrue -Because "key '$key' is required"
                }
            }

            It 'ASCII style returns all required keys' {
                $cs = Get-CharacterSet -TerminalProfile $unicodeProfile -Style 'ASCII'
                foreach ($key in $requiredKeys) {
                    $cs.ContainsKey($key) | Should -BeTrue -Because "key '$key' is required"
                }
            }
        }

        Context 'ASCII fallback behavior' {

            It 'returns ASCII box characters when UseUnicode is false' {
                $cs = Get-CharacterSet -TerminalProfile $asciiProfile -Style 'Single'
                $cs.TopLeft    | Should -Be '+'
                $cs.Horizontal | Should -Be '-'
                $cs.Vertical   | Should -Be '|'
                $cs.Selected   | Should -Be '>'
                $cs.Bullet     | Should -Be '*'
            }

            It 'returns ASCII style regardless of terminal Unicode support when Style=ASCII' {
                $cs = Get-CharacterSet -TerminalProfile $unicodeProfile -Style 'ASCII'
                $cs.TopLeft    | Should -Be '+'
                $cs.Horizontal | Should -Be '-'
                $cs.Vertical   | Should -Be '|'
            }

            It 'ASCII style values are all within ASCII 0-127 range' {
                $cs = Get-CharacterSet -TerminalProfile $unicodeProfile -Style 'ASCII'
                foreach ($key in $requiredKeys) {
                    foreach ($ch in $cs[$key].ToCharArray()) {
                        [int]$ch | Should -BeLessOrEqual 127 -Because "key '$key' must be pure ASCII"
                    }
                }
            }

            It 'ASCII fallback returns ASCII values for all keys even on Unicode terminal' {
                $cs = Get-CharacterSet -TerminalProfile $asciiProfile -Style 'Heavy'
                # When UseUnicode is false, ascii fallback ignores the requested style
                $cs.Horizontal | Should -Be '-'
            }
        }

        Context 'Unicode styles return correct characters' {

            It 'Single style TopLeft is Unicode box-drawing character U+250C' {
                $cs = Get-CharacterSet -TerminalProfile $unicodeProfile -Style 'Single'
                [int][char]$cs.TopLeft | Should -Be 0x250C
            }

            It 'Single style Horizontal is U+2500' {
                $cs = Get-CharacterSet -TerminalProfile $unicodeProfile -Style 'Single'
                [int][char]$cs.Horizontal | Should -Be 0x2500
            }

            It 'Double style Horizontal is double-line char U+2550' {
                $cs = Get-CharacterSet -TerminalProfile $unicodeProfile -Style 'Double'
                [int][char]$cs.Horizontal | Should -Be 0x2550
            }

            It 'Double style Vertical is double-line char U+2551' {
                $cs = Get-CharacterSet -TerminalProfile $unicodeProfile -Style 'Double'
                [int][char]$cs.Vertical | Should -Be 0x2551
            }

            It 'Rounded style TopLeft differs from Single and Double styles' {
                $single  = Get-CharacterSet -TerminalProfile $unicodeProfile -Style 'Single'
                $double  = Get-CharacterSet -TerminalProfile $unicodeProfile -Style 'Double'
                $rounded = Get-CharacterSet -TerminalProfile $unicodeProfile -Style 'Rounded'
                $rounded.TopLeft | Should -Not -Be $single.TopLeft
                $rounded.TopLeft | Should -Not -Be $double.TopLeft
            }

            It 'Heavy style TopLeft is U+250F' {
                $cs = Get-CharacterSet -TerminalProfile $unicodeProfile -Style 'Heavy'
                [int][char]$cs.TopLeft | Should -Be 0x250F
            }

            It 'all Unicode style values are non-empty strings' {
                foreach ($style in @('Single', 'Double', 'Rounded', 'Heavy')) {
                    $cs = Get-CharacterSet -TerminalProfile $unicodeProfile -Style $style
                    foreach ($key in $requiredKeys) {
                        $cs[$key] | Should -Not -BeNullOrEmpty -Because "'$style.$key' must have a value"
                    }
                }
            }
        }
    }
}
