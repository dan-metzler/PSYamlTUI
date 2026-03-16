#Requires -Version 5.1
<#
    Resolve-TokenContext.Tests.ps1

    Tests for the token substitution pipeline implemented inside Read-MenuFile.
    There is no standalone Resolve-TokenContext function -- substitution is applied
    directly inside Read-MenuFile before YAML parsing. These tests verify the
    end-to-end behavior of loading vars.yaml, merging -Context, and substituting
    {{key}} tokens throughout the menu tree.
#>
# Import at script level -- runs during Pester discovery so InModuleScope finds the module.
$script:_repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:_modulePath = Join-Path -Path (Join-Path -Path $script:_repoRoot -ChildPath 'Source') -ChildPath 'PSYamlTUI.psd1'
Import-Module -Name $script:_modulePath -Force

AfterAll {
    Remove-Module -Name PSYamlTUI -ErrorAction SilentlyContinue
}

InModuleScope PSYamlTUI {

    Describe 'Token substitution via Read-MenuFile' {

        BeforeAll {
            # Defined in BeforeAll so it is available during test execution.
            # (Pester 5: function definitions outside BeforeAll only exist at discovery time.)
            function New-TempFile {
                param([string]$Content, [string]$Name)
                $p = Join-Path -Path $TestDrive -ChildPath $Name
                Set-Content -Path $p -Value $Content -Encoding UTF8
                return $p
            }
        }

        Context 'no vars file and no context' {

            It 'loads a menu.yaml with no tokens without error' {
                $yaml = @'
menu:
  title: "Plain Menu"
  items:
    - label: "Exit"
      exit: true
'@
                $path = New-TempFile -Content $yaml -Name 'plain.menu.yaml'
                { Read-MenuFile -Path $path } | Should -Not -Throw
            }

            It 'leaves unknown {{tokens}} as-is in label values' {
                $yaml = @'
menu:
  title: "{{appName}}"
  items:
    - label: "Deploy to {{environment}}"
      exit: true
'@
                $path = New-TempFile -Content $yaml -Name 'no-vars.menu.yaml'
                $result = Read-MenuFile -Path $path
                # Tokens are unreplaced -- left verbatim
                $result.Title          | Should -Be '{{appName}}'
                $result.Items[0].Label | Should -Be 'Deploy to {{environment}}'
            }
        }

        Context 'loading vars.yaml via -VarsPath' {

            It 'substitutes tokens in the title from vars.yaml' {
                $varsYaml = "vars:`n  appName: TestApp"
                $menuYaml = "menu:`n  title: '{{appName}}'`n  items:`n    - label: Exit`n      exit: true"
                $varsPath = New-TempFile -Content $varsYaml -Name 'app.vars.yaml'
                $menuPath = New-TempFile -Content $menuYaml -Name 'app.menu.yaml'
                $result = Read-MenuFile -Path $menuPath -VarsPath $varsPath
                $result.Title | Should -Be 'TestApp'
            }

            It 'substitutes tokens in item label values' {
                $varsYaml = "vars:`n  env: prod"
                $menuYaml = "menu:`n  title: T`n  items:`n    - label: 'Deploy to {{env}}'`n      exit: true"
                $varsPath = New-TempFile -Content $varsYaml -Name 'lbl.vars.yaml'
                $menuPath = New-TempFile -Content $menuYaml -Name 'lbl.menu.yaml'
                $result = Read-MenuFile -Path $menuPath -VarsPath $varsPath
                $result.Items[0].Label | Should -Be 'Deploy to prod'
            }

            It 'substitutes tokens in call: values' {
                $varsYaml = "vars:`n  scriptsPath: ./myscripts"
                $menuYaml = @'
menu:
  title: T
  items:
    - label: Run
      call: "{{scriptsPath}}/deploy.ps1"
'@
                $varsPath = New-TempFile -Content $varsYaml -Name 'call.vars.yaml'
                $menuPath = New-TempFile -Content $menuYaml -Name 'call.menu.yaml'
                $result = Read-MenuFile -Path $menuPath -VarsPath $varsPath
                $result.Items[0].Call | Should -Be './myscripts/deploy.ps1'
            }

            It 'substitutes tokens in description: values' {
                $varsYaml = "vars:`n  env: staging"
                $menuYaml = @'
menu:
  title: T
  items:
    - label: Run
      description: "Running against {{env}}"
      call: Invoke-Deploy
'@
                $varsPath = New-TempFile -Content $varsYaml -Name 'desc.vars.yaml'
                $menuPath = New-TempFile -Content $menuYaml -Name 'desc.menu.yaml'
                $result = Read-MenuFile -Path $menuPath -VarsPath $varsPath
                $result.Items[0].Description | Should -Be 'Running against staging'
            }

            It 'substitutes tokens in params: values' {
                $varsYaml = "vars:`n  env: prod"
                $menuYaml = @'
menu:
  title: T
  items:
    - label: Run
      call: Invoke-Deploy
      params:
        environment: "{{env}}"
'@
                $varsPath = New-TempFile -Content $varsYaml -Name 'params.vars.yaml'
                $menuPath = New-TempFile -Content $menuYaml -Name 'params.menu.yaml'
                $result = Read-MenuFile -Path $menuPath -VarsPath $varsPath
                $result.Items[0].Params['environment'] | Should -Be 'prod'
            }

            It 'substitutes tokens in before.params values' {
                $varsYaml = "vars:`n  tenant: my-tenant"
                $menuYaml = @'
menu:
  title: T
  items:
    - label: Run
      before:
        hook: Assert-Auth
        params:
          tenant: "{{tenant}}"
      call: Invoke-Deploy
'@
                $varsPath = New-TempFile -Content $varsYaml -Name 'hookp.vars.yaml'
                $menuPath = New-TempFile -Content $menuYaml -Name 'hookp.menu.yaml'
                $result = Read-MenuFile -Path $menuPath -VarsPath $varsPath
                $result.Items[0].Before[0].Params['tenant'] | Should -Be 'my-tenant'
            }

            It 'substitutes tokens in import: paths' {
                $subYaml = "items:`n  - label: Sub`n    exit: true"
                $subPath = New-TempFile -Content $subYaml -Name 'sub-import.yaml'
                $varsYaml = "vars:`n  subFile: sub-import.yaml"
                $menuYaml = @'
menu:
  title: T
  items:
    - label: Section
      import: "./{{subFile}}"
    - label: Exit
      exit: true
'@
                $varsPath = New-TempFile -Content $varsYaml -Name 'imp.vars.yaml'
                $menuPath = New-TempFile -Content $menuYaml -Name 'imp.menu.yaml'
                $result = Read-MenuFile -Path $menuPath -VarsPath $varsPath
                $result.Items[0].NodeType | Should -Be 'BRANCH'
                $result.Items[0].Children[0].Label | Should -Be 'Sub'
            }

            It 'throws when VarsPath does not exist' {
                $menuPath = New-TempFile -Content $script:SimpleMenuYaml -Name 'v-missing.menu.yaml'
                $fakePath = Join-Path -Path $TestDrive -ChildPath 'nonexistent.vars.yaml'
                { Read-MenuFile -Path $menuPath -VarsPath $fakePath } | Should -Throw -ExpectedMessage '*not found*'
            }

            It 'throws when vars.yaml has no top-level vars: key' {
                $badVars = "settings:`n  env: prod"
                $varsPath = New-TempFile -Content $badVars -Name 'bad.vars.yaml'
                $menuPath = New-TempFile -Content $script:SimpleMenuYaml -Name 'bv.menu.yaml'
                { Read-MenuFile -Path $menuPath -VarsPath $varsPath } | Should -Throw -ExpectedMessage '*vars*'
            }

            It 'leaves unknown tokens unreplaced -- does not throw' {
                $varsYaml = "vars:`n  knownKey: hello"
                $menuYaml = "menu:`n  title: '{{knownKey}} and {{unknownToken}}'`n  items:`n    - label: E`n      exit: true"
                $varsPath = New-TempFile -Content $varsYaml -Name 'unk.vars.yaml'
                $menuPath = New-TempFile -Content $menuYaml -Name 'unk.menu.yaml'
                $result = Read-MenuFile -Path $menuPath -VarsPath $varsPath
                $result.Title | Should -Be 'hello and {{unknownToken}}'
            }
        }

        Context '-Context hashtable' {

            It '-Context value substitutes into menu title' {
                $menuYaml = "menu:`n  title: '{{user}}'`n  items:`n    - label: E`n      exit: true"
                $menuPath = New-TempFile -Content $menuYaml -Name 'ctx.menu.yaml'
                $result = Read-MenuFile -Path $menuPath -Context @{ user = 'TestUser' }
                $result.Title | Should -Be 'TestUser'
            }

            It '-Context value wins over vars.yaml value for the same key' {
                $varsYaml = "vars:`n  env: dev"
                $menuYaml = "menu:`n  title: '{{env}}'`n  items:`n    - label: E`n      exit: true"
                $varsPath = New-TempFile -Content $varsYaml -Name 'win.vars.yaml'
                $menuPath = New-TempFile -Content $menuYaml -Name 'win.menu.yaml'
                $result = Read-MenuFile -Path $menuPath -VarsPath $varsPath -Context @{ env = 'production' }
                $result.Title | Should -Be 'production'
            }

            It '-Context and vars.yaml keys are merged (non-conflicting keys both apply)' {
                $varsYaml = "vars:`n  appName: MyApp"
                $menuYaml = "menu:`n  title: '{{appName}} on {{env}}'`n  items:`n    - label: E`n      exit: true"
                $varsPath = New-TempFile -Content $varsYaml -Name 'merge.vars.yaml'
                $menuPath = New-TempFile -Content $menuYaml -Name 'merge.menu.yaml'
                $result = Read-MenuFile -Path $menuPath -VarsPath $varsPath -Context @{ env = 'prod' }
                $result.Title | Should -Be 'MyApp on prod'
            }
        }

        Context 'Windows paths in vars.yaml' {

            It 'Windows backslash paths substitute correctly without requiring double backslash' {
                # Single-quoted YAML values have no escape processing -- backslashes are literal
                $varsYaml = "vars:`n  scriptsPath: 'C:\scripts\myapp'"
                $menuYaml = @'
menu:
  title: T
  items:
    - label: Run
      call: '{{scriptsPath}}\run.ps1'
'@
                $varsPath = New-TempFile -Content $varsYaml -Name 'win.vars.yaml'
                $menuPath = New-TempFile -Content $menuYaml -Name 'win.menu.yaml'
                $result = Read-MenuFile -Path $menuPath -VarsPath $varsPath
                $result.Items[0].Call | Should -Be 'C:\scripts\myapp\run.ps1'
            }
        }
    }
}
