#Requires -Version 5.1
# Import at script level -- this runs during Pester discovery so InModuleScope finds the module.
$script:_repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:_modulePath = Join-Path -Path (Join-Path -Path $script:_repoRoot -ChildPath 'Source') -ChildPath 'PSYamlTUI.psd1'
Import-Module -Name $script:_modulePath -Force

AfterAll {
    Remove-Module -Name PSYamlTUI -ErrorAction SilentlyContinue
}

InModuleScope PSYamlTUI {

    Describe 'Invoke-MenuAction' {

        BeforeAll {
            # Node factory helpers -- defined here so they are available during
            # test execution (Pester 5: discovery-time function defs are not in scope).
            function New-ScriptNode {
                param([string]$Call, [hashtable]$Params = @{}, [bool]$Confirm = $false)
                [PSCustomObject]@{
                    NodeType    = 'SCRIPT'
                    Label       = 'Test Script'
                    Description = $null
                    Hotkey      = $null
                    Call        = $Call
                    Params      = $Params
                    Confirm     = $Confirm
                    Before      = @()
                }
            }

            function New-FunctionNode {
                param([string]$Call, [hashtable]$Params = @{}, [bool]$Confirm = $false)
                [PSCustomObject]@{
                    NodeType    = 'FUNCTION'
                    Label       = 'Test Function'
                    Description = $null
                    Hotkey      = $null
                    Call        = $Call
                    Params      = $Params
                    Confirm     = $Confirm
                    Before      = @()
                }
            }

            # Root dir for tests -- all script paths are resolved relative to this
            $script:RootDir = $TestDrive

            # Create a real .ps1 file that the SCRIPT tests can actually execute
            $scriptContent = @'
param([string]$Env = 'default', [string]$Role = '')
$global:InvokeMenuAction_LastEnv  = $Env
$global:InvokeMenuAction_LastRole = $Role
'@
            $scriptFile = Join-Path -Path $TestDrive -ChildPath 'test-action.ps1'
            Set-Content -Path $scriptFile -Value $scriptContent -Encoding UTF8

            # A script that records which params it received via a module-scope variable
            $paramScript = @'
param([string]$Name, [bool]$Flag = $false)
$global:InvokeMenuAction_Param_Name = $Name
$global:InvokeMenuAction_Param_Flag = $Flag
'@
            $paramFile = Join-Path -Path $TestDrive -ChildPath 'param-action.ps1'
            Set-Content -Path $paramFile -Value $paramScript -Encoding UTF8

            # A function equivalent for function-type tests
            function global:Invoke-TestMenuFunction {
                param([string]$Env = 'default')
                $script:InvokeMenuAction_FunctionCalled = $true
                $script:InvokeMenuAction_FunctionEnv = $Env
            }
        }

        AfterAll {
            Remove-Item -Path Function:\Invoke-TestMenuFunction -ErrorAction SilentlyContinue
        }

        BeforeEach {
            $global:InvokeMenuAction_LastEnv = $null
            $global:InvokeMenuAction_LastRole = $null
            $global:InvokeMenuAction_Param_Name = $null
            $global:InvokeMenuAction_Param_Flag = $null
            $script:InvokeMenuAction_FunctionCalled = $false
            $script:InvokeMenuAction_FunctionEnv = $null
        }

        Context 'SCRIPT node execution' {

            It 'executes a .ps1 script via the & operator (no Invoke-Expression)' {
                $node = New-ScriptNode -Call './test-action.ps1'
                { Invoke-MenuAction -Node $node -RootDir $script:RootDir } |
                Should -Not -Throw
            }

            It 'sets module-scope sentinel confirming script was invoked' {
                $node = New-ScriptNode -Call './test-action.ps1' -Params @{ Env = 'prod' }
                Invoke-MenuAction -Node $node -RootDir $script:RootDir
                $global:InvokeMenuAction_LastEnv | Should -Be 'prod'
            }

            It 'passes params to the script via splatting' {
                $node = New-ScriptNode -Call './param-action.ps1' -Params @{ Name = 'Alice'; Flag = 'true' }
                Invoke-MenuAction -Node $node -RootDir $script:RootDir
                $global:InvokeMenuAction_Param_Name | Should -Be 'Alice'
            }

            It 'converts YAML string "true" param value to native $true' {
                $node = New-ScriptNode -Call './param-action.ps1' -Params @{ Name = 'test'; Flag = 'true' }
                Invoke-MenuAction -Node $node -RootDir $script:RootDir
                $global:InvokeMenuAction_Param_Flag | Should -BeTrue
            }

            It 'converts YAML string "false" param value to native $false' {
                $node = New-ScriptNode -Call './param-action.ps1' -Params @{ Name = 'test'; Flag = 'false' }
                Invoke-MenuAction -Node $node -RootDir $script:RootDir
                $global:InvokeMenuAction_Param_Flag | Should -BeFalse
            }
        }

        Context 'SCRIPT node -- path canonicalization and root jail' {

            It 'canonicalizes a relative script path against RootDir before execution' {
                # ./test-action.ps1 is relative -- it must resolve inside RootDir
                $node = New-ScriptNode -Call './test-action.ps1'
                { Invoke-MenuAction -Node $node -RootDir $script:RootDir } |
                Should -Not -Throw
            }

            It 'throws when script file does not exist' {
                $node = New-ScriptNode -Call './scripts/nonexistent-script.ps1'
                { Invoke-MenuAction -Node $node -RootDir $script:RootDir } |
                Should -Throw
            }

            It 'error message for missing script includes the resolved path' {
                $node = New-ScriptNode -Call './scripts/no-such-file.ps1'
                try {
                    Invoke-MenuAction -Node $node -RootDir $script:RootDir
                }
                catch {
                    $_.Exception.Message | Should -Match 'no-such-file.ps1'
                }
            }

            It 'throws when script path traverses out of root dir via ../' {
                $node = New-ScriptNode -Call '../../evil.ps1'
                { Invoke-MenuAction -Node $node -RootDir $script:RootDir } |
                Should -Throw -ExpectedMessage '*Security*'
            }

            It 'throws when script path is absolute (outside root dir)' {
                $node = New-ScriptNode -Call 'C:\Windows\System32\evil.ps1'
                { Invoke-MenuAction -Node $node -RootDir $script:RootDir } |
                Should -Throw -ExpectedMessage '*Security*'
            }

            It 'throws when script path is in a sibling directory whose name starts with the root dir name' {
                # e.g. RootDir = C:\root, path = C:\root_sibling\evil.ps1
                # The old StartsWith check would pass; the separator-aware check correctly rejects it.
                $sep  = [System.IO.Path]::DirectorySeparatorChar
                $sibling = $script:RootDir.TrimEnd($sep) + '_sibling' + $sep + 'evil.ps1'
                $node = New-ScriptNode -Call $sibling
                { Invoke-MenuAction -Node $node -RootDir $script:RootDir } |
                Should -Throw -ExpectedMessage '*Security*'
            }

            It 'root jail error message mentions the original call value' {
                $node = New-ScriptNode -Call '../../escape.ps1'
                try {
                    Invoke-MenuAction -Node $node -RootDir $script:RootDir
                }
                catch {
                    $_.Exception.Message | Should -Match 'Security'
                }
            }
        }

        Context 'FUNCTION node execution' {

            It 'executes a PowerShell function via the & operator' {
                $node = New-FunctionNode -Call 'Invoke-TestMenuFunction'
                Invoke-MenuAction -Node $node -RootDir $script:RootDir
                $script:InvokeMenuAction_FunctionCalled | Should -BeTrue
            }

            It 'passes params to the function via splatting' {
                $node = New-FunctionNode -Call 'Invoke-TestMenuFunction' -Params @{ Env = 'staging' }
                Invoke-MenuAction -Node $node -RootDir $script:RootDir
                $script:InvokeMenuAction_FunctionEnv | Should -Be 'staging'
            }

            It 'validates function exists via Get-Command before calling' {
                $node = New-FunctionNode -Call 'Invoke-NonExistentFunctionForTesting'
                { Invoke-MenuAction -Node $node -RootDir $script:RootDir } |
                Should -Throw
            }

            It 'error message for unknown function includes the function name' {
                $node = New-FunctionNode -Call 'Invoke-NoSuchFunc99'
                try {
                    Invoke-MenuAction -Node $node -RootDir $script:RootDir
                }
                catch {
                    $_.Exception.Message | Should -Match 'Invoke-NoSuchFunc99'
                }
            }
        }

        Context 'unexpected NodeType' {

            It 'throws a descriptive error for an unexpected NodeType' {
                $node = [PSCustomObject]@{ NodeType = 'INVALID'; Call = 'foo'; Params = $null }
                { Invoke-MenuAction -Node $node -RootDir $script:RootDir } |
                Should -Throw -ExpectedMessage '*NodeType*'
            }
        }

        Context 'Invoke-Expression is never used' {

            It 'does not call Invoke-Expression during script execution' {
                Mock -CommandName 'Invoke-Expression' -MockWith {
                    throw 'Invoke-Expression was called -- this is forbidden'
                }
                $node = New-ScriptNode -Call './test-action.ps1'
                { Invoke-MenuAction -Node $node -RootDir $script:RootDir } |
                Should -Not -Throw
            }

            It 'does not call Invoke-Expression during function execution' {
                Mock -CommandName 'Invoke-Expression' -MockWith {
                    throw 'Invoke-Expression was called -- this is forbidden'
                }
                $node = New-FunctionNode -Call 'Invoke-TestMenuFunction'
                { Invoke-MenuAction -Node $node -RootDir $script:RootDir } |
                Should -Not -Throw
            }
        }
    }
}
