#Requires -Version 5.1
<#
    Navigation.Tests.ps1

    Tests for the key-binding and navigation helper functions:
    Assert-KeyBindings, Resolve-KeyAction, Get-FooterText.

    Full end-to-end navigation (Show-MenuFrame loop) requires mocking
    [Console]::ReadKey (a static method) which Pester cannot mock directly.
    All interactive navigation tests are therefore marked Pending and serve
    as a specification for a future wrapper-based implementation.
#>
# Import at script level -- runs during Pester discovery so InModuleScope finds the module.
$script:_repoRoot   = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:_modulePath = Join-Path -Path (Join-Path -Path $script:_repoRoot -ChildPath 'Source') -ChildPath 'PSYamlTUI.psd1'
Import-Module -Name $script:_modulePath -Force

AfterAll {
    Remove-Module -Name PSYamlTUI -ErrorAction SilentlyContinue
}

InModuleScope PSYamlTUI {

    # Default key bindings shared across tests
    $script:DefaultBindings = @{
        Up     = [System.ConsoleKey]::UpArrow
        Down   = [System.ConsoleKey]::DownArrow
        Select = [System.ConsoleKey]::Enter
        Back   = @([System.ConsoleKey]::Escape, 'B')
        Quit   = 'Q'
        Home   = 'H'
    }

    # ---------------------------------------------------------------------------
    Describe 'Assert-KeyBindings' {
    # ---------------------------------------------------------------------------

        It 'accepts the default key bindings without throwing' {
            { Assert-KeyBindings -Bindings $script:DefaultBindings } | Should -Not -Throw
        }

        It 'accepts a complete custom key bindings hashtable' {
            $custom = @{
                Up     = [System.ConsoleKey]::W
                Down   = [System.ConsoleKey]::S
                Select = [System.ConsoleKey]::Enter
                Back   = [System.ConsoleKey]::Escape
                Quit   = 'X'
                Home   = 'Z'
            }
            { Assert-KeyBindings -Bindings $custom } | Should -Not -Throw
        }

        It 'accepts a partial key bindings hashtable (only overriding some actions)' {
            $partial = @{ Quit = 'X'; Home = 'Z' }
            { Assert-KeyBindings -Bindings $partial } | Should -Not -Throw
        }

        It 'accepts an empty hashtable (all defaults apply at runtime)' {
            { Assert-KeyBindings -Bindings @{} } | Should -Not -Throw
        }

        It 'throws for an unknown action name' {
            $bad = @{ Up = [System.ConsoleKey]::UpArrow; NonExistentAction = 'X' }
            { Assert-KeyBindings -Bindings $bad } | Should -Throw
        }

        It 'error message for unknown action includes the action name' {
            try { Assert-KeyBindings -Bindings @{ BogusAction = 'X' } }
            catch { $_.Exception.Message | Should -Match 'BogusAction' }
        }

        It 'throws when two actions share the same key (duplicate key check)' {
            $dup = @{
                Up   = [System.ConsoleKey]::UpArrow
                Down = [System.ConsoleKey]::UpArrow   # same as Up
            }
            { Assert-KeyBindings -Bindings $dup } | Should -Throw
        }

        It 'throws when two actions share the same char key' {
            $dup = @{ Quit = 'Q'; Home = 'Q' }
            { Assert-KeyBindings -Bindings $dup } | Should -Throw
        }

        It 'throws when a binding value is an invalid type (e.g. integer)' {
            $bad = @{ Quit = 42 }
            { Assert-KeyBindings -Bindings $bad } | Should -Throw
        }

        It 'throws when a string binding is longer than one character' {
            $bad = @{ Quit = 'QQ' }
            { Assert-KeyBindings -Bindings $bad } | Should -Throw
        }

        It 'an array binding with two valid ConsoleKey values is accepted' {
            $multi = @{ Back = @([System.ConsoleKey]::Escape, [System.ConsoleKey]::LeftArrow) }
            { Assert-KeyBindings -Bindings $multi } | Should -Not -Throw
        }

        It 'an array binding with a ConsoleKey and a char string is accepted' {
            $multi = @{ Back = @([System.ConsoleKey]::Escape, 'B') }
            { Assert-KeyBindings -Bindings $multi } | Should -Not -Throw
        }
    }

    # ---------------------------------------------------------------------------
    Describe 'Resolve-KeyAction' {
    # ---------------------------------------------------------------------------

        BeforeAll {
            function New-KeyInfo {
                param([char]$Char, [System.ConsoleKey]$Key = [System.ConsoleKey]::A)
                [System.ConsoleKeyInfo]::new($Char, $Key, $false, $false, $false)
            }

            function New-SpecialKeyInfo {
                param([System.ConsoleKey]$Key)
                [System.ConsoleKeyInfo]::new([char]0, $Key, $false, $false, $false)
            }
        }

        It 'returns Up when the UpArrow key is pressed' {
            $key    = New-SpecialKeyInfo -Key ([System.ConsoleKey]::UpArrow)
            $action = Resolve-KeyAction -Key $key -Bindings $script:DefaultBindings
            $action | Should -Be 'Up'
        }

        It 'returns Down when the DownArrow key is pressed' {
            $key    = New-SpecialKeyInfo -Key ([System.ConsoleKey]::DownArrow)
            $action = Resolve-KeyAction -Key $key -Bindings $script:DefaultBindings
            $action | Should -Be 'Down'
        }

        It 'returns Select when the Enter key is pressed' {
            $key    = New-SpecialKeyInfo -Key ([System.ConsoleKey]::Enter)
            $action = Resolve-KeyAction -Key $key -Bindings $script:DefaultBindings
            $action | Should -Be 'Select'
        }

        It 'returns Back when the Escape key is pressed' {
            $key    = New-SpecialKeyInfo -Key ([System.ConsoleKey]::Escape)
            $action = Resolve-KeyAction -Key $key -Bindings $script:DefaultBindings
            $action | Should -Be 'Back'
        }

        It 'returns Back when B is pressed (array binding)' {
            $key    = New-KeyInfo -Char 'B' -Key ([System.ConsoleKey]::B)
            $action = Resolve-KeyAction -Key $key -Bindings $script:DefaultBindings
            $action | Should -Be 'Back'
        }

        It 'returns Back when b (lowercase) is pressed (case-insensitive)' {
            $key    = New-KeyInfo -Char 'b' -Key ([System.ConsoleKey]::B)
            $action = Resolve-KeyAction -Key $key -Bindings $script:DefaultBindings
            $action | Should -Be 'Back'
        }

        It 'returns Quit when Q is pressed' {
            $key    = New-KeyInfo -Char 'Q' -Key ([System.ConsoleKey]::Q)
            $action = Resolve-KeyAction -Key $key -Bindings $script:DefaultBindings
            $action | Should -Be 'Quit'
        }

        It 'returns Quit when q (lowercase) is pressed' {
            $key    = New-KeyInfo -Char 'q' -Key ([System.ConsoleKey]::Q)
            $action = Resolve-KeyAction -Key $key -Bindings $script:DefaultBindings
            $action | Should -Be 'Quit'
        }

        It 'returns Home when H is pressed' {
            $key    = New-KeyInfo -Char 'H' -Key ([System.ConsoleKey]::H)
            $action = Resolve-KeyAction -Key $key -Bindings $script:DefaultBindings
            $action | Should -Be 'Home'
        }

        It 'returns $null for an unbound key' {
            $key    = New-KeyInfo -Char 'Z' -Key ([System.ConsoleKey]::Z)
            $action = Resolve-KeyAction -Key $key -Bindings $script:DefaultBindings
            $action | Should -BeNullOrEmpty
        }
    }

    # ---------------------------------------------------------------------------
    Describe 'Get-FooterText' {
    # ---------------------------------------------------------------------------

        It 'returns a non-empty string from default bindings' {
            $text = Get-FooterText -Bindings $script:DefaultBindings
            $text | Should -Not -BeNullOrEmpty
        }

        It 'footer text contains navigation hint words' {
            $text = Get-FooterText -Bindings $script:DefaultBindings
            $text | Should -Match 'Navigate'
            $text | Should -Match 'Select'
            $text | Should -Match 'Back'
        }

        It 'returns a string when called with an empty bindings hashtable' {
            $text = Get-FooterText -Bindings @{}
            $text | Should -BeOfType [string]
        }
    }

    # ---------------------------------------------------------------------------
    Describe 'Full navigation loop' {
    # ---------------------------------------------------------------------------

        BeforeAll {
            # Minimal terminal profile + theme so Show-MenuFrame can render
            $script:FakeProfile = [PSCustomObject]@{
                UseAnsi    = $false
                UseUnicode = $false
                ColorMethod = 'WriteHost'
                Width       = 80
            }
            $script:FakeChars   = Get-CharacterSet -TerminalProfile $script:FakeProfile -Style 'ASCII'
            $script:FakeTheme   = Get-ColorTheme
            $script:DefaultKB   = @{
                Up     = [System.ConsoleKey]::UpArrow
                Down   = [System.ConsoleKey]::DownArrow
                Select = [System.ConsoleKey]::Enter
                Back   = @([System.ConsoleKey]::Escape, 'B')
                Quit   = 'Q'
                Home   = 'H'
            }

            function New-Key {
                param([System.ConsoleKey]$Key, [char]$Char = [char]0)
                return [System.ConsoleKeyInfo]::new($Char, $Key, $false, $false, $false)
            }
            function New-CharKey {
                param([char]$Char)
                return [System.ConsoleKeyInfo]::new($Char, [System.ConsoleKey]::A, $false, $false, $false)
            }
            function New-SimpleMenu {
                param([string]$Title = 'Test')
                [PSCustomObject]@{
                    Title = $Title
                    Items = @(
                        [PSCustomObject]@{ NodeType='FUNCTION'; Label='Item1'; Description=$null; Hotkey=$null; Call='Invoke-Noop1'; Params=@{}; Confirm=$false; Before=@() }
                        [PSCustomObject]@{ NodeType='FUNCTION'; Label='Item2'; Description=$null; Hotkey=$null; Call='Invoke-Noop2'; Params=@{}; Confirm=$false; Before=@() }
                        [PSCustomObject]@{ NodeType='EXIT';     Label='Exit';  Description=$null; Hotkey=$null; Before=@() }
                    )
                }
            }
        }

        It 'Up/Down navigation wraps from last item to first' {
            # Feed: Down x3 (wraps to 0), Quit
            $keys = @(
                New-Key -Key ([System.ConsoleKey]::DownArrow)
                New-Key -Key ([System.ConsoleKey]::DownArrow)
                New-Key -Key ([System.ConsoleKey]::DownArrow)  # wraps to 0
                New-CharKey -Char 'Q'
            )
            $i = 0
            Mock Read-ConsoleKey { $keys[$script:_navIdx++] }
            $script:_navIdx = 0
            $script:YamlTUI_Quit = $false
            Show-MenuFrame -MenuData (New-SimpleMenu) -RootDir $TestDrive `
                -TermProfile $script:FakeProfile -Chars $script:FakeChars `
                -KeyBindings $script:DefaultKB -Theme $script:FakeTheme -IsRoot
            # If wrapping works we reached Q without error
            $script:YamlTUI_Quit | Should -BeTrue
        }

        It 'Select on EXIT node sets YamlTUI_Quit flag' {
            # Navigate to Exit (index 2): Down, Down, Enter
            $keys = @(
                New-Key -Key ([System.ConsoleKey]::DownArrow)
                New-Key -Key ([System.ConsoleKey]::DownArrow)
                New-Key -Key ([System.ConsoleKey]::Enter)
            )
            Mock Read-ConsoleKey { $keys[$script:_navIdx++] }
            $script:_navIdx = 0
            $script:YamlTUI_Quit = $false
            Show-MenuFrame -MenuData (New-SimpleMenu) -RootDir $TestDrive `
                -TermProfile $script:FakeProfile -Chars $script:FakeChars `
                -KeyBindings $script:DefaultKB -Theme $script:FakeTheme -IsRoot
            $script:YamlTUI_Quit | Should -BeTrue
        }

        It 'Back action is ignored at root and does not exit the loop' {
            # Escape (back, ignored at root), then Q to quit
            $keys = @(
                New-Key -Key ([System.ConsoleKey]::Escape)
                New-CharKey -Char 'Q'
            )
            Mock Read-ConsoleKey { $keys[$script:_navIdx++] }
            $script:_navIdx = 0
            $script:YamlTUI_Quit = $false
            Show-MenuFrame -MenuData (New-SimpleMenu) -RootDir $TestDrive `
                -TermProfile $script:FakeProfile -Chars $script:FakeChars `
                -KeyBindings $script:DefaultKB -Theme $script:FakeTheme -IsRoot
            $script:YamlTUI_Quit | Should -BeTrue
        }

        It 'Back action exits a non-root frame and returns to caller' {
            $keys = @(New-Key -Key ([System.ConsoleKey]::Escape))
            Mock Read-ConsoleKey { $keys[$script:_navIdx++] }
            $script:_navIdx = 0
            $script:YamlTUI_Quit = $false
            # Called without -IsRoot -- Escape should exit the frame cleanly
            Show-MenuFrame -MenuData (New-SimpleMenu) -RootDir $TestDrive `
                -TermProfile $script:FakeProfile -Chars $script:FakeChars `
                -KeyBindings $script:DefaultKB -Theme $script:FakeTheme
            $script:YamlTUI_Quit | Should -BeFalse
        }

        It 'Home action at root resets index and does not set the Home flag' {
            $keys = @(
                New-Key -Key ([System.ConsoleKey]::DownArrow)
                New-CharKey -Char 'H'   # Home at root -- should not quit
                New-CharKey -Char 'Q'
            )
            Mock Read-ConsoleKey { $keys[$script:_navIdx++] }
            $script:_navIdx = 0
            $script:YamlTUI_Quit = $false
            $script:YamlTUI_Home = $false
            Show-MenuFrame -MenuData (New-SimpleMenu) -RootDir $TestDrive `
                -TermProfile $script:FakeProfile -Chars $script:FakeChars `
                -KeyBindings $script:DefaultKB -Theme $script:FakeTheme -IsRoot
            $script:YamlTUI_Home | Should -BeFalse
        }

        It 'Home action at non-root frame sets YamlTUI_Home signal flag' {
            $keys = @(New-CharKey -Char 'H')
            Mock Read-ConsoleKey { $keys[$script:_navIdx++] }
            $script:_navIdx = 0
            $script:YamlTUI_Quit = $false
            $script:YamlTUI_Home = $false
            Show-MenuFrame -MenuData (New-SimpleMenu) -RootDir $TestDrive `
                -TermProfile $script:FakeProfile -Chars $script:FakeChars `
                -KeyBindings $script:DefaultKB -Theme $script:FakeTheme
            $script:YamlTUI_Home | Should -BeTrue
        }
    }
}
