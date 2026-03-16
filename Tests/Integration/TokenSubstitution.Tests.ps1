#Requires -Version 5.1
<#
    TokenSubstitution.Tests.ps1

    Integration tests for the full token substitution pipeline.
    These tests use the static Fixture files and verify that a real
    menu.yaml + vars.yaml pair loads correctly with all tokens resolved.
#>
# Import at script level -- runs during Pester discovery so InModuleScope finds the module.
$script:_repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:_modulePath = Join-Path -Path (Join-Path -Path $script:_repoRoot -ChildPath 'Source') -ChildPath 'PSYamlTUI.psd1'
Import-Module -Name $script:_modulePath -Force

# Re-import at execution time -- the top-level Import-Module only runs during discovery.
# Preceding test files may have removed the module via AfterAll by the time this file executes.
BeforeAll {
    Import-Module -Name $script:_modulePath -Force
}

AfterAll {
    Remove-Module -Name PSYamlTUI -ErrorAction SilentlyContinue
}

InModuleScope PSYamlTUI {

    # Compute fixture paths using $PSScriptRoot, which Pester reliably preserves in all
    # test blocks including inside InModuleScope. This file lives in Tests/Integration/,
    # so its parent is Tests/ and Fixtures/ is a sibling of Integration/ under Tests/.
    BeforeAll {
        $testsDir = Split-Path -Path $PSScriptRoot -Parent
        $fixturesRoot = Join-Path -Path $testsDir -ChildPath 'Fixtures'
        $script:FixtureMenus = Join-Path -Path $fixturesRoot -ChildPath 'menus'
        $script:FixtureVars = Join-Path -Path $fixturesRoot -ChildPath 'vars'
    }

    Describe 'Full pipeline: menu.yaml + vars.yaml token substitution' {

        Context 'tokens.menu.yaml with simple.vars.yaml' {

            BeforeAll {
                $menuPath = Join-Path -Path $script:FixtureMenus -ChildPath 'tokens.menu.yaml'
                $varsPath = Join-Path -Path $script:FixtureVars  -ChildPath 'simple.vars.yaml'
                $script:TokenResult = Read-MenuFile -Path $menuPath -VarsPath $varsPath
            }

            It 'loads tokens.menu.yaml with simple.vars.yaml without error' {
                $script:TokenResult | Should -Not -BeNullOrEmpty
            }

            It 'menu title has the appName token substituted' {
                $script:TokenResult.Title | Should -Be 'TestApp'
            }

            It 'item label has the environment token substituted' {
                $script:TokenResult.Items[0].Label | Should -Be 'Deploy to test'
            }

            It 'item call has the scriptsPath token substituted' {
                $script:TokenResult.Items[0].Call | Should -Be './scripts/deploy.ps1'
            }

            It 'item params have the environment token substituted' {
                $script:TokenResult.Items[0].Params['env'] | Should -Be 'test'
            }
        }

        Context '-Context overrides vars.yaml values' {

            It '-Context value replaces the vars.yaml value for the same key' {
                $menuPath = Join-Path -Path $script:FixtureMenus -ChildPath 'tokens.menu.yaml'
                $varsPath = Join-Path -Path $script:FixtureVars  -ChildPath 'simple.vars.yaml'
                $result = Read-MenuFile -Path $menuPath -VarsPath $varsPath -Context @{ environment = 'prod' }
                $result.Items[0].Label | Should -Be 'Deploy to prod'
            }

            It '-Context value for appName overrides the vars.yaml appName' {
                $menuPath = Join-Path -Path $script:FixtureMenus -ChildPath 'tokens.menu.yaml'
                $varsPath = Join-Path -Path $script:FixtureVars  -ChildPath 'simple.vars.yaml'
                $result = Read-MenuFile -Path $menuPath -VarsPath $varsPath -Context @{ appName = 'OverrideApp' }
                $result.Title | Should -Be 'OverrideApp'
            }
        }

        Context 'no vars.yaml, no -Context' {

            It 'menu with tokens but no vars loads without error and tokens remain as-is' {
                $menuPath = Join-Path -Path $script:FixtureMenus -ChildPath 'tokens.menu.yaml'
                $result = Read-MenuFile -Path $menuPath
                # Tokens must be left verbatim when no substitution source is provided
                $result.Title          | Should -Be '{{appName}}'
                $result.Items[0].Label | Should -Be 'Deploy to {{environment}}'
            }
        }

        Context 'hooks.menu.yaml validates successfully (hook names, no substitution)' {

            BeforeAll {
                $menuPath = Join-Path -Path $script:FixtureMenus -ChildPath 'hooks.menu.yaml'
                $script:HooksResult = Read-MenuFile -Path $menuPath
            }

            It 'loads hooks.menu.yaml without error' {
                $script:HooksResult | Should -Not -BeNullOrEmpty
            }

            It 'branch node has the expected before hook' {
                $branch = $script:HooksResult.Items[0]
                $branch.NodeType           | Should -Be 'BRANCH'
                $branch.Before.Count       | Should -Be 1
                $branch.Before[0].Hook     | Should -Be 'Test-BranchHook'
            }

            It 'child leaf node has the expected before hook from string shorthand' {
                $leaf = $script:HooksResult.Items[0].Children[0]
                $leaf.Before.Count     | Should -Be 1
                $leaf.Before[0].Hook   | Should -Be 'Test-LeafHook'
            }
        }

        Context 'import-root.menu.yaml resolves nested imports' {

            BeforeAll {
                $menuPath = Join-Path -Path $script:FixtureMenus -ChildPath 'import-root.menu.yaml'
                $script:ImportResult = Read-MenuFile -Path $menuPath
            }

            It 'loads import-root.menu.yaml including the nested import chain' {
                $script:ImportResult | Should -Not -BeNullOrEmpty
                $script:ImportResult.Title | Should -Be 'Import Test'
            }

            It 'import-sub.yaml items are available as children of the first item' {
                $branch = $script:ImportResult.Items[0]
                $branch.NodeType          | Should -Be 'BRANCH'
                $branch.Label             | Should -Be 'Imported Section'
                $branch.Children          | Should -Not -BeNullOrEmpty
                $branch.Children[0].Label | Should -Be 'Sub Action'
            }

            It 'nested import (import-sub2.yaml) is resolved as a BRANCH inside import-sub' {
                $nestedBranch = $script:ImportResult.Items[0].Children[1]
                $nestedBranch.NodeType | Should -Be 'BRANCH'
                $nestedBranch.Children[0].Label | Should -Be 'Deep Sub Action'
            }
        }

        Context 'windows-paths.vars.yaml' {

            BeforeAll {
                # Use a menu that references a token that will be a Windows path
                $yaml = @'
menu:
  title: "Windows Path Test"
  items:
    - label: "Run Script"
      call: '{{scriptsPath}}/run.ps1'
    - label: "Exit"
      exit: true
'@
                $menuPath = Join-Path -Path $TestDrive -ChildPath 'winpath.menu.yaml'
                Set-Content -Path $menuPath -Value $yaml -Encoding UTF8
                $varsPath = Join-Path -Path $script:FixtureVars -ChildPath 'windows-paths.vars.yaml'
                $script:WinPathResult = Read-MenuFile -Path $menuPath -VarsPath $varsPath
            }

            It 'loads windows-paths.vars.yaml without error' {
                $script:WinPathResult | Should -Not -BeNullOrEmpty
            }

            It 'Windows backslash path from vars.yaml substitutes correctly' {
                $script:WinPathResult.Items[0].Call | Should -Be 'C:\scripts\myapp/run.ps1'
            }
        }
    }
}

