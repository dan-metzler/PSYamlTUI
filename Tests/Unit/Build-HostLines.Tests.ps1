#Requires -Version 5.1
# Import at script level -- this runs during Pester discovery so InModuleScope finds the module.
$script:_repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:_modulePath = Join-Path -Path (Join-Path -Path $script:_repoRoot -ChildPath 'Source') -ChildPath 'PSYamlTUI.psd1'
Import-Module -Name $script:_modulePath -Force

AfterAll {
    Remove-Module -Name PSYamlTUI -ErrorAction SilentlyContinue
}

InModuleScope PSYamlTUI {

    Describe 'Build-HostLines' {

        BeforeAll {
            $script:asciiProfile = [PSCustomObject]@{
                UseUnicode  = $false
                UseAnsi     = $false
                ColorMethod = 'WriteHost'
                Width       = 80
            }

            $script:chars = Get-CharacterSet -TerminalProfile $script:asciiProfile -Style 'ASCII'
            $script:theme = Get-ColorTheme -Theme @{
                Border          = 'DarkCyan'
                Title           = 'White'
                ItemDefault     = 'Gray'
                ItemSelected    = 'Yellow'
                ItemDescription = 'DarkGray'
                FooterText      = 'DarkGray'
            }

            $script:items = @(
                [PSCustomObject]@{
                    NodeType    = 'FUNCTION'
                    Label       = 'Selected Item'
                    Description = 'Selected item description'
                    Hotkey      = $null
                    Call        = 'Invoke-Thing'
                    Params      = @{}
                    Confirm     = $false
                    Before      = @()
                }
                [PSCustomObject]@{
                    NodeType    = 'EXIT'
                    Label       = 'Exit'
                    Description = $null
                    Hotkey      = $null
                    Before      = @()
                }
            )
        }

        It 'keeps title borders in Border color when title text has a different color' {
            $footerText = 'Footer Sentinel'
            $lines = Build-HostLines -Title 'Title Sentinel' -Items $script:items -SelectedIndex 0 `
                -Breadcrumb @() -InnerWidth 50 -Chars $script:chars -FooterText $footerText -Theme $script:theme

            $titleLine = $lines | Where-Object {
                $null -ne $_.Segments -and
                $_.Segments.Count -eq 3 -and
                $_.Segments[1].Text -match 'Title Sentinel'
            } | Select-Object -First 1

            $titleLine | Should -Not -BeNullOrEmpty
            $titleLine.Segments[0].Color | Should -Be $script:theme.Border
            $titleLine.Segments[2].Color | Should -Be $script:theme.Border
            $titleLine.Segments[1].Color | Should -Be $script:theme.Title
        }

        It 'keeps selected item borders in Border color when item text uses ItemSelected color' {
            $footerText = 'Footer Sentinel'
            $lines = Build-HostLines -Title 'Menu' -Items $script:items -SelectedIndex 0 `
                -Breadcrumb @() -InnerWidth 50 -Chars $script:chars -FooterText $footerText -Theme $script:theme

            $selectedLine = $lines | Where-Object {
                $null -ne $_.Segments -and
                $_.Segments.Count -eq 3 -and
                $_.Segments[1].Text -match 'Selected Item'
            } | Select-Object -First 1

            $selectedLine | Should -Not -BeNullOrEmpty
            $selectedLine.Segments[0].Color | Should -Be $script:theme.Border
            $selectedLine.Segments[2].Color | Should -Be $script:theme.Border
            $selectedLine.Segments[1].Color | Should -Be $script:theme.ItemSelected
        }

        It 'keeps footer borders in Border color when footer text uses FooterText color' {
            $footerText = 'Footer Sentinel'
            $lines = Build-HostLines -Title 'Menu' -Items $script:items -SelectedIndex 0 `
                -Breadcrumb @() -InnerWidth 50 -Chars $script:chars -FooterText $footerText -Theme $script:theme

            $footerLine = $lines | Where-Object {
                $null -ne $_.Segments -and
                $_.Segments.Count -eq 3 -and
                $_.Segments[1].Text -match $footerText
            } | Select-Object -First 1

            $footerLine | Should -Not -BeNullOrEmpty
            $footerLine.Segments[0].Color | Should -Be $script:theme.Border
            $footerLine.Segments[2].Color | Should -Be $script:theme.Border
            $footerLine.Segments[1].Color | Should -Be $script:theme.FooterText
        }
    }
}
