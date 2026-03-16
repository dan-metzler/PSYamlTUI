#Requires -Version 5.1
# Import at script level -- this runs during Pester discovery so InModuleScope finds the module.
$script:_repoRoot   = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:_modulePath = Join-Path -Path (Join-Path -Path $script:_repoRoot -ChildPath 'Source') -ChildPath 'PSYamlTUI.psd1'
Import-Module -Name $script:_modulePath -Force

AfterAll {
    Remove-Module -Name PSYamlTUI -ErrorAction SilentlyContinue
}

InModuleScope PSYamlTUI {

    Describe 'Invoke-BeforeHook' {

        BeforeAll {
            # Define hook test functions at global scope so Get-Command finds them.
            # Each function is removed in AfterAll to avoid leaking into other tests.
            function global:Test-HookPass   { return $true }
            function global:Test-HookFail   { return $false }
            function global:Test-HookThrow  { throw 'Hook intentionally threw' }

            # Param-capturing hook: stores received args in module-scoped vars for assertion
            function global:Test-HookWithParams {
                param([string]$Role, [string]$Tenant, [bool]$IsAdmin)
                $script:CapturedRole    = $Role
                $script:CapturedTenant  = $Tenant
                $script:CapturedIsAdmin = $IsAdmin
                return $true
            }

            # Counter hook: increments a call counter on each invocation
            function global:Test-HookCounter {
                $script:HookCallCount++
                return $true
            }
        }

        AfterAll {
            Remove-Item -Path Function:\Test-HookPass        -ErrorAction SilentlyContinue
            Remove-Item -Path Function:\Test-HookFail        -ErrorAction SilentlyContinue
            Remove-Item -Path Function:\Test-HookThrow       -ErrorAction SilentlyContinue
            Remove-Item -Path Function:\Test-HookWithParams  -ErrorAction SilentlyContinue
            Remove-Item -Path Function:\Test-HookCounter     -ErrorAction SilentlyContinue
        }

        BeforeEach {
            $script:CapturedRole    = $null
            $script:CapturedTenant  = $null
            $script:CapturedIsAdmin = $null
            $script:HookCallCount   = 0
        }

        Context 'single hook execution' {

            It 'returns $true when the hook function returns $true' {
                $hooks = @(@{ Hook = 'Test-HookPass'; Params = @{} })
                $result = Invoke-BeforeHook -Hooks $hooks
                $result | Should -BeTrue
            }

            It 'returns $false when the hook function returns $false' {
                $hooks = @(@{ Hook = 'Test-HookFail'; Params = @{} })
                $result = Invoke-BeforeHook -Hooks $hooks
                $result | Should -BeFalse
            }

            It 'propagates an exception thrown by the hook' {
                $hooks = @(@{ Hook = 'Test-HookThrow'; Params = @{} })
                { Invoke-BeforeHook -Hooks $hooks } | Should -Throw -ExpectedMessage '*intentionally threw*'
            }
        }

        Context 'multiple hooks -- ordering and early exit' {

            It 'runs all hooks in order and returns $true when all pass' {
                $hooks = @(
                    @{ Hook = 'Test-HookCounter'; Params = @{} },
                    @{ Hook = 'Test-HookCounter'; Params = @{} },
                    @{ Hook = 'Test-HookCounter'; Params = @{} }
                )
                $result = Invoke-BeforeHook -Hooks $hooks
                $result               | Should -BeTrue
                $script:HookCallCount | Should -Be 3
            }

            It 'stops executing remaining hooks when one returns $false' {
                $hooks = @(
                    @{ Hook = 'Test-HookCounter'; Params = @{} },
                    @{ Hook = 'Test-HookFail';    Params = @{} },
                    @{ Hook = 'Test-HookCounter'; Params = @{} }
                )
                $result = Invoke-BeforeHook -Hooks $hooks
                $result               | Should -BeFalse
                # Counter should only have been incremented once (before the fail)
                $script:HookCallCount | Should -Be 1
            }

            It 'returns $false when the first hook fails' {
                $hooks = @(
                    @{ Hook = 'Test-HookFail';    Params = @{} },
                    @{ Hook = 'Test-HookCounter'; Params = @{} }
                )
                $result = Invoke-BeforeHook -Hooks $hooks
                $result               | Should -BeFalse
                $script:HookCallCount | Should -Be 0
            }
        }

        Context 'parameter passing' {

            It 'passes string params to the hook function via splatting' {
                $hooks = @(@{
                    Hook   = 'Test-HookWithParams'
                    Params = @{ Role = 'admin'; Tenant = 'acme' }
                })
                Invoke-BeforeHook -Hooks $hooks
                $script:CapturedRole   | Should -Be 'admin'
                $script:CapturedTenant | Should -Be 'acme'
            }

            It 'converts YAML string "true" to native $true before passing' {
                $hooks = @(@{
                    Hook   = 'Test-HookWithParams'
                    Params = @{ Role = 'user'; IsAdmin = 'true' }
                })
                Invoke-BeforeHook -Hooks $hooks
                $script:CapturedIsAdmin | Should -BeTrue
            }

            It 'converts YAML string "false" to native $false before passing' {
                $hooks = @(@{
                    Hook   = 'Test-HookWithParams'
                    Params = @{ Role = 'user'; IsAdmin = 'false' }
                })
                Invoke-BeforeHook -Hooks $hooks
                $script:CapturedIsAdmin | Should -BeFalse
            }

            It 'passes an empty hashtable when no params are defined on the hook' {
                # Test-HookPass accepts no params -- calling it with empty splat should not throw
                $hooks = @(@{ Hook = 'Test-HookPass'; Params = @{} })
                { Invoke-BeforeHook -Hooks $hooks } | Should -Not -Throw
            }
        }

        Context 'validation -- function not found' {

            It 'throws a descriptive error when the hook function does not exist' {
                $hooks = @(@{ Hook = 'Invoke-NonExistentHookFunction99'; Params = @{} })
                { Invoke-BeforeHook -Hooks $hooks } | Should -Throw
            }

            It 'error message for missing function includes the function name' {
                $hooks = @(@{ Hook = 'Invoke-MissingHookXYZ'; Params = @{} })
                try {
                    Invoke-BeforeHook -Hooks $hooks
                }
                catch {
                    $_.Exception.Message | Should -Match 'Invoke-MissingHookXYZ'
                }
            }
        }

        Context 'validation -- bad hook names rejected at runtime (defense-in-depth)' {

            It 'throws a descriptive error when hook name contains a forward slash' {
                $hooks = @(@{ Hook = 'path/to/BadHook'; Params = @{} })
                { Invoke-BeforeHook -Hooks $hooks } | Should -Throw
            }

            It 'throws a descriptive error when hook name contains a backslash' {
                $hooks = @(@{ Hook = 'path\to\BadHook'; Params = @{} })
                { Invoke-BeforeHook -Hooks $hooks } | Should -Throw
            }

            It 'throws a descriptive error when hook name has a .ps1 extension' {
                $hooks = @(@{ Hook = 'Assert-Auth.ps1'; Params = @{} })
                { Invoke-BeforeHook -Hooks $hooks } | Should -Throw
            }

            It 'throws a descriptive error when hook name has any file extension' {
                $hooks = @(@{ Hook = 'Assert-Auth.exe'; Params = @{} })
                { Invoke-BeforeHook -Hooks $hooks } | Should -Throw
            }
        }

        Context 'hook function validation uses Get-Command -CommandType Function' {

            It 'finds a valid function defined in the session' {
                # Test-HookPass was defined in BeforeAll -- it must be found
                $hooks = @(@{ Hook = 'Test-HookPass'; Params = @{} })
                { Invoke-BeforeHook -Hooks $hooks } | Should -Not -Throw
            }

            It 'does not accept a cmdlet name in place of a function' {
                # Get-Process is a cmdlet not a Function -- should be rejected
                $hooks = @(@{ Hook = 'Get-Process'; Params = @{} })
                { Invoke-BeforeHook -Hooks $hooks } | Should -Throw
            }
        }
    }
}
