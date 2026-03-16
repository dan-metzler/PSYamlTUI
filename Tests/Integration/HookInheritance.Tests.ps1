#Requires -Version 5.1
<#
    HookInheritance.Tests.ps1

    Integration tests for before hook execution ordering and inheritance.
    Tests verify that:
    - Hooks run in the correct order (outermost ancestor first)
    - A failing hook in a chain stops subsequent hooks and execution
    - Hook params are scoped to their own hook entry

    Full Show-MenuFrame inheritance (BRANCH propagation to children at navigation
    time) requires mocking [Console]::ReadKey -- those cases are marked Pending.
    The hook execution contract itself is fully testable via Invoke-BeforeHook
    with manually assembled hook chains.
#>
# Import at script level -- runs during Pester discovery so InModuleScope finds the module.
$script:_repoRoot   = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:_modulePath = Join-Path -Path (Join-Path -Path $script:_repoRoot -ChildPath 'Source') -ChildPath 'PSYamlTUI.psd1'
Import-Module -Name $script:_modulePath -Force

AfterAll {
    Remove-Module -Name PSYamlTUI -ErrorAction SilentlyContinue
}

InModuleScope PSYamlTUI {

    Describe 'Hook inheritance and execution order' {

        BeforeAll {
            # Execution order tracker -- each hook appends its name to this list
            $script:HookExecutionOrder = [System.Collections.Generic.List[string]]::new()

            function global:Test-InheritHook1 {
                $script:HookExecutionOrder.Add('Hook1')
                return $true
            }

            function global:Test-InheritHook2 {
                $script:HookExecutionOrder.Add('Hook2')
                return $true
            }

            function global:Test-InheritHook3 {
                $script:HookExecutionOrder.Add('Hook3')
                return $true
            }

            function global:Test-InheritFailHook {
                $script:HookExecutionOrder.Add('FailHook')
                return $false
            }

            function global:Test-InheritThrowHook {
                $script:HookExecutionOrder.Add('ThrowHook')
                throw 'Inherited hook threw'
            }

            # Param-scoping hooks: each records only its own param
            function global:Test-Hook-Role {
                param([string]$Role)
                $script:CapturedRole = $Role
                return $true
            }

            function global:Test-Hook-Tenant {
                param([string]$Tenant)
                $script:CapturedTenant = $Tenant
                return $true
            }
        }

        AfterAll {
            Remove-Item -Path Function:\Test-InheritHook1    -ErrorAction SilentlyContinue
            Remove-Item -Path Function:\Test-InheritHook2    -ErrorAction SilentlyContinue
            Remove-Item -Path Function:\Test-InheritHook3    -ErrorAction SilentlyContinue
            Remove-Item -Path Function:\Test-InheritFailHook -ErrorAction SilentlyContinue
            Remove-Item -Path Function:\Test-InheritThrowHook -ErrorAction SilentlyContinue
            Remove-Item -Path Function:\Test-Hook-Role       -ErrorAction SilentlyContinue
            Remove-Item -Path Function:\Test-Hook-Tenant     -ErrorAction SilentlyContinue
        }

        BeforeEach {
            $script:HookExecutionOrder.Clear()
            $script:CapturedRole   = $null
            $script:CapturedTenant = $null
        }

        Context 'execution order' {

            It 'runs hooks in list order -- first hook runs first' {
                $hooks = @(
                    @{ Hook = 'Test-InheritHook1'; Params = @{} },
                    @{ Hook = 'Test-InheritHook2'; Params = @{} },
                    @{ Hook = 'Test-InheritHook3'; Params = @{} }
                )
                Invoke-BeforeHook -Hooks $hooks
                $script:HookExecutionOrder[0] | Should -Be 'Hook1'
                $script:HookExecutionOrder[1] | Should -Be 'Hook2'
                $script:HookExecutionOrder[2] | Should -Be 'Hook3'
            }

            It 'a branch hook runs before a node-level hook when combined into one chain' {
                # Simulates: inherited hooks (branch) prepended, node hooks appended
                $branchHook = @{ Hook = 'Test-InheritHook1'; Params = @{} }
                $nodeHook   = @{ Hook = 'Test-InheritHook2'; Params = @{} }
                $combined   = @($branchHook, $nodeHook)
                Invoke-BeforeHook -Hooks $combined
                $script:HookExecutionOrder[0] | Should -Be 'Hook1'
                $script:HookExecutionOrder[1] | Should -Be 'Hook2'
            }

            It 'two ancestor branch hooks run before the node-level hook' {
                $grandparentHook = @{ Hook = 'Test-InheritHook1'; Params = @{} }
                $parentHook      = @{ Hook = 'Test-InheritHook2'; Params = @{} }
                $nodeHook        = @{ Hook = 'Test-InheritHook3'; Params = @{} }
                $combined        = @($grandparentHook, $parentHook, $nodeHook)
                Invoke-BeforeHook -Hooks $combined
                $script:HookExecutionOrder[0] | Should -Be 'Hook1'
                $script:HookExecutionOrder[1] | Should -Be 'Hook2'
                $script:HookExecutionOrder[2] | Should -Be 'Hook3'
            }
        }

        Context 'a failing hook stops the chain' {

            It 'inherited hook returning $false blocks remaining hooks' {
                $hooks = @(
                    @{ Hook = 'Test-InheritHook1';    Params = @{} },
                    @{ Hook = 'Test-InheritFailHook'; Params = @{} },
                    @{ Hook = 'Test-InheritHook2';    Params = @{} }
                )
                $result = Invoke-BeforeHook -Hooks $hooks
                $result                                       | Should -BeFalse
                $script:HookExecutionOrder.Count              | Should -Be 2
                $script:HookExecutionOrder -contains 'Hook2' | Should -BeFalse
            }

            It 'inherited hook throwing stops the chain and propagates the exception' {
                $hooks = @(
                    @{ Hook = 'Test-InheritHook1';     Params = @{} },
                    @{ Hook = 'Test-InheritThrowHook'; Params = @{} },
                    @{ Hook = 'Test-InheritHook2';     Params = @{} }
                )
                { Invoke-BeforeHook -Hooks $hooks } | Should -Throw -ExpectedMessage '*Inherited hook threw*'
                # Hook2 must NOT have run
                $script:HookExecutionOrder -contains 'Hook2' | Should -BeFalse
            }
        }

        Context 'hook params are scoped to their own hook' {

            It 'two hooks in a chain each receive only their own params' {
                $hooks = @(
                    @{ Hook = 'Test-Hook-Role';   Params = @{ Role   = 'admin' } },
                    @{ Hook = 'Test-Hook-Tenant'; Params = @{ Tenant = 'acme'  } }
                )
                Invoke-BeforeHook -Hooks $hooks
                $script:CapturedRole   | Should -Be 'admin'
                $script:CapturedTenant | Should -Be 'acme'
            }
        }

        Context 'Read-MenuFile produces correct inherited hook structure' {

            It 'branch node Before array is populated and child nodes also have their own Before arrays' {
                $yaml = @'
menu:
  title: "T"
  items:
    - label: "Gated Section"
      before:
        hook: "Assert-BranchAuth"
        params:
          role: "admin"
      children:
        - label: "Gated Action"
          before: "Assert-LeafAuth"
          call: "Invoke-GatedAction"
'@
                $path = Join-Path -Path $TestDrive -ChildPath 'inh.menu.yaml'
                Set-Content -Path $path -Value $yaml -Encoding UTF8

                $result = Read-MenuFile -Path $path
                $branch = $result.Items[0]
                $leaf   = $branch.Children[0]

                # Branch has its own Before hook
                $branch.Before.Count   | Should -Be 1
                $branch.Before[0].Hook | Should -Be 'Assert-BranchAuth'

                # Child has its own node-level Before hook
                $leaf.Before.Count   | Should -Be 1
                $leaf.Before[0].Hook | Should -Be 'Assert-LeafAuth'
            }

            It 'branch node hook params are correctly parsed' {
                $yaml = @'
menu:
  title: "T"
  items:
    - label: "Gated"
      before:
        hook: "Test-BranchHook"
        params:
          role: "admin"
          scope: "write"
      children:
        - label: "Child"
          exit: true
'@
                $path = Join-Path -Path $TestDrive -ChildPath 'bparam.menu.yaml'
                Set-Content -Path $path -Value $yaml -Encoding UTF8

                $result = Read-MenuFile -Path $path
                $branch = $result.Items[0]
                $branch.Before[0].Params['role']  | Should -Be 'admin'
                $branch.Before[0].Params['scope'] | Should -Be 'write'
            }
        }

        Context 'full Show-MenuFrame inheritance (pending -- requires console mocking)' {

            # Skipped: [Console]::ReadKey cannot be mocked without a wrapper function
            It 'branch node before: hook runs when child leaf node is selected' -Skip {}

            It 'branch node before: hook runs before rendering the child submenu' -Skip {}

            It 'child node before: hook runs after the inherited parent branch hook' -Skip {}
        }
    }
}
