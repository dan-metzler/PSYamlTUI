#Requires -Version 5.1
# Import at script level -- this runs during Pester discovery so InModuleScope finds the module.
$script:_repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:_modulePath = Join-Path -Path (Join-Path -Path $script:_repoRoot -ChildPath 'Source') -ChildPath 'PSYamlTUI.psd1'
Import-Module -Name $script:_modulePath -Force

AfterAll {
  Remove-Module -Name PSYamlTUI -ErrorAction SilentlyContinue
}

InModuleScope PSYamlTUI {

  # ---------------------------------------------------------------------------
  # Helper: write a YAML string to a temp file and return the absolute path.
  # Defined in BeforeAll so it is available during test execution.
  # (Pester 5: function definitions outside BeforeAll only exist at discovery time.)
  # ---------------------------------------------------------------------------
  BeforeAll {
    function New-TempMenuFile {
      param([string]$Content, [string]$FileName = 'test.menu.yaml')
      $path = Join-Path -Path $TestDrive -ChildPath $FileName
      Set-Content -Path $path -Value $Content -Encoding UTF8
      return $path
    }
  }

  # A minimal valid root menu YAML used as baseline across many tests.
  $script:SimpleMenuYaml = @'
menu:
  title: "Simple"
  items:
    - label: "Exit"
      exit: true
'@

  # ---------------------------------------------------------------------------
  Describe 'Read-MenuFile - YAML loading' {
    # ---------------------------------------------------------------------------

    It 'loads a valid root menu.yaml and returns an object with Title and Items' {
      $path = New-TempMenuFile -Content $script:SimpleMenuYaml
      $result = Read-MenuFile -Path $path
      $result          | Should -Not -BeNullOrEmpty
      $result.Title    | Should -Be 'Simple'
      $result.Items    | Should -Not -BeNullOrEmpty
    }

    It 'returns Items as a proper array (not scalar) when the menu has exactly one item' {
      # Regression: PS pipeline unwrapping caused Resolve-MenuItems to return a plain
      # PSCustomObject (not an array) for single-item menus. Items.Count was $null,
      # making the index-mode validity check (0 -lt $null) silently fail.
      $path = New-TempMenuFile -Content $script:SimpleMenuYaml
      $result = Read-MenuFile -Path $path
      $result.Items.Count            | Should -Be 1
      # Pipe the boolean, not the array itself -- piping an array sends its elements,
      # not the array object, so BeOfType would receive the single PSCustomObject element.
      ($result.Items -is [array]) | Should -BeTrue
    }

    It 'returns the correct number of items from a root menu file' {
      $yaml = @'
menu:
  title: "Two Items"
  items:
    - label: "Item A"
      exit: true
    - label: "Item B"
      exit: true
'@
      $path = New-TempMenuFile -Content $yaml
      $result = Read-MenuFile -Path $path
      $result.Items.Count | Should -Be 2
    }

    It 'handles an empty children array gracefully -- actually expects a throw since empty children is invalid' {
      $yaml = @'
menu:
  title: "Empty Children"
  items:
    - label: "Branch"
      children: []
'@
      $path = New-TempMenuFile -Content $yaml
      { Read-MenuFile -Path $path } | Should -Throw
    }

    It 'throws a descriptive error when the file does not exist' {
      $fakePath = Join-Path -Path $TestDrive -ChildPath 'nonexistent.yaml'
      { Read-MenuFile -Path $fakePath } | Should -Throw
    }

    It 'error message for missing file includes the path' {
      $fakePath = Join-Path -Path $TestDrive -ChildPath 'missing.menu.yaml'
      try {
        Read-MenuFile -Path $fakePath
      }
      catch {
        $_.Exception.Message | Should -Match 'missing.menu.yaml'
      }
    }

    It 'throws a descriptive error when the YAML is malformed' {
      $badYaml = "menu:`n  title: `"unterminated"
      $path = New-TempMenuFile -Content $badYaml
      { Read-MenuFile -Path $path } | Should -Throw
    }

    It 'throws when root file has no top-level menu key' {
      $yaml = "items:`n  - label: orphan`n    exit: true"
      $path = New-TempMenuFile -Content $yaml
      { Read-MenuFile -Path $path } | Should -Throw -ExpectedMessage '*menu*'
    }

    It 'throws when menu key is present but has no items array' {
      $yaml = "menu:`n  title: Empty"
      $path = New-TempMenuFile -Content $yaml
      { Read-MenuFile -Path $path } | Should -Throw -ExpectedMessage '*items*'
    }

    It 'loads a submenu file referenced via import: key' {
      $subYaml = "items:`n  - label: SubItem`n    exit: true"
      Set-Content -Path (Join-Path -Path $TestDrive -ChildPath 'sub.yaml') -Value $subYaml -Encoding UTF8
      $rootYaml = @'
menu:
  title: "Root with Import"
  items:
    - label: "Imported"
      import: "./sub.yaml"
    - label: "Exit"
      exit: true
'@
      $path = New-TempMenuFile -Content $rootYaml
      $result = Read-MenuFile -Path $path
      $result.Items.Count    | Should -Be 2
      $result.Items[0].Label | Should -Be 'Imported'
      # Import creates a BRANCH with the sub file's items as children
      $result.Items[0].NodeType | Should -Be 'BRANCH'
    }

    It 'resolves nested import chains (import inside an imported file)' {
      $sub2Yaml = "items:`n  - label: Deepest`n    exit: true"
      Set-Content -Path (Join-Path -Path $TestDrive -ChildPath 'sub2.yaml') -Value $sub2Yaml -Encoding UTF8

      $sub1Yaml = "items:`n  - label: Level1`n    exit: true`n  - label: Nested`n    import: './sub2.yaml'"
      Set-Content -Path (Join-Path -Path $TestDrive -ChildPath 'sub1.yaml') -Value $sub1Yaml -Encoding UTF8

      $rootYaml = @'
menu:
  title: "Chain"
  items:
    - label: "Level0"
      import: "./sub1.yaml"
    - label: "Exit"
      exit: true
'@
      $path = New-TempMenuFile -Content $rootYaml
      $result = Read-MenuFile -Path $path
      $result.Items[0].NodeType | Should -Be 'BRANCH'
      # Nested item inside the import resolves into another BRANCH
      $result.Items[0].Children[1].NodeType | Should -Be 'BRANCH'
    }
  }

  # ---------------------------------------------------------------------------
  Describe 'Read-MenuFile - node type inference' {
    # ---------------------------------------------------------------------------

    It 'infers EXIT node when exit: true is present' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "Go Away"
      exit: true
'@
      $path = New-TempMenuFile -Content $yaml
      $result = Read-MenuFile -Path $path
      $result.Items[0].NodeType | Should -Be 'EXIT'
    }

    It 'infers BRANCH node when children: key is present' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "Branch"
      children:
        - label: "Child"
          exit: true
'@
      $path = New-TempMenuFile -Content $yaml
      $result = Read-MenuFile -Path $path
      $result.Items[0].NodeType | Should -Be 'BRANCH'
    }

    It 'infers BRANCH node when import: key is present' {
      $subYaml = "items:`n  - label: S`n    exit: true"
      Set-Content -Path (Join-Path -Path $TestDrive -ChildPath 'infer.sub.yaml') -Value $subYaml -Encoding UTF8
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "Imported Branch"
      import: "./infer.sub.yaml"
    - label: "Exit"
      exit: true
'@
      $path = New-TempMenuFile -Content $yaml
      $result = Read-MenuFile -Path $path
      $result.Items[0].NodeType | Should -Be 'BRANCH'
    }

    It 'infers SCRIPT node when call: ends in .ps1' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "Script"
      call: "./scripts/do-thing.ps1"
'@
      $path = New-TempMenuFile -Content $yaml
      $result = Read-MenuFile -Path $path
      $result.Items[0].NodeType | Should -Be 'SCRIPT'
    }

    It 'infers SCRIPT node when call: contains a forward slash' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "Script"
      call: "scripts/do-thing.ps1"
'@
      $path = New-TempMenuFile -Content $yaml
      $result = Read-MenuFile -Path $path
      $result.Items[0].NodeType | Should -Be 'SCRIPT'
    }

    It 'infers SCRIPT node when call: contains a backslash' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "Script"
      call: 'scripts\do-thing.ps1'
'@
      $path = New-TempMenuFile -Content $yaml
      $result = Read-MenuFile -Path $path
      $result.Items[0].NodeType | Should -Be 'SCRIPT'
    }

    It 'infers FUNCTION node when call: is a plain function name without extension or path chars' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "Func"
      call: "Invoke-MyFunction"
'@
      $path = New-TempMenuFile -Content $yaml
      $result = Read-MenuFile -Path $path
      $result.Items[0].NodeType | Should -Be 'FUNCTION'
    }

    It 'does not infer SCRIPT when call: is a plain name with no dots' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "Func"
      call: "Get-Process"
'@
      $path = New-TempMenuFile -Content $yaml
      $result = Read-MenuFile -Path $path
      $result.Items[0].NodeType | Should -Be 'FUNCTION'
    }
  }

  # ---------------------------------------------------------------------------
  Describe 'Read-MenuFile - validation rules' {
    # ---------------------------------------------------------------------------

    It 'throws when a node has both children: and import:' {
      $subYaml = "items:`n  - label: S`n    exit: true"
      Set-Content -Path (Join-Path -Path $TestDrive -ChildPath 'conflict.sub.yaml') -Value $subYaml -Encoding UTF8
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "Conflict"
      import: "./conflict.sub.yaml"
      children:
        - label: "Child"
          exit: true
'@
      $path = New-TempMenuFile -Content $yaml
      { Read-MenuFile -Path $path } | Should -Throw
    }

    It 'throws when a node has both children: and call:' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "BadNode"
      call: "Some-Function"
      children:
        - label: "Child"
          exit: true
'@
      $path = New-TempMenuFile -Content $yaml
      { Read-MenuFile -Path $path } | Should -Throw
    }

    It 'throws when a node has both import: and call:' {
      $subYaml = "items:`n  - label: S`n    exit: true"
      Set-Content -Path (Join-Path -Path $TestDrive -ChildPath 'ic.sub.yaml') -Value $subYaml -Encoding UTF8
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "BadNode"
      call: "Some-Function"
      import: "./ic.sub.yaml"
'@
      $path = New-TempMenuFile -Content $yaml
      { Read-MenuFile -Path $path } | Should -Throw
    }

    It 'throws when import: path is absolute (Windows style)' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "AbsImport"
      import: "C:/some/absolute/path.yaml"
    - label: "Exit"
      exit: true
'@
      $path = New-TempMenuFile -Content $yaml
      { Read-MenuFile -Path $path } | Should -Throw -ExpectedMessage '*absolute*'
    }

    It 'throws when import: path is absolute (Unix style)' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "AbsImport"
      import: "/etc/menus/bad.yaml"
    - label: "Exit"
      exit: true
'@
      $path = New-TempMenuFile -Content $yaml
      { Read-MenuFile -Path $path } | Should -Throw
    }

    It 'throws when call: contains a pipe character' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "Inject"
      call: "Get-Process | Out-File result.txt"
'@
      $path = New-TempMenuFile -Content $yaml
      { Read-MenuFile -Path $path } | Should -Throw
    }

    It 'throws when call: contains a semicolon' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "Inject"
      call: "Get-Process; Remove-Item important.txt"
'@
      $path = New-TempMenuFile -Content $yaml
      { Read-MenuFile -Path $path } | Should -Throw
    }

    It 'throws when call: contains an ampersand' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "Inject"
      call: "Start-Sleep 5 & badcmd"
'@
      $path = New-TempMenuFile -Content $yaml
      { Read-MenuFile -Path $path } | Should -Throw
    }

    It 'throws when call: contains a redirect operator >' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "Inject"
      call: "Get-Process > out.txt"
'@
      $path = New-TempMenuFile -Content $yaml
      { Read-MenuFile -Path $path } | Should -Throw
    }

    It 'throws when hotkey: is longer than one character' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "Func"
      hotkey: "AB"
      call: "Some-Func"
'@
      $path = New-TempMenuFile -Content $yaml
      { Read-MenuFile -Path $path } | Should -Throw
    }

    It 'throws when params: contains a nested object' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "Func"
      call: "Some-Func"
      params:
        nested:
          key: value
'@
      $path = New-TempMenuFile -Content $yaml
      { Read-MenuFile -Path $path } | Should -Throw
    }

    It 'throws when a before hook name contains a path separator' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "Func"
      before: "path/to/BadHook"
      call: "Some-Func"
'@
      $path = New-TempMenuFile -Content $yaml
      { Read-MenuFile -Path $path } | Should -Throw
    }

    It 'throws when a before hook name contains a file extension' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "Func"
      before: "BadHook.ps1"
      call: "Some-Func"
'@
      $path = New-TempMenuFile -Content $yaml
      { Read-MenuFile -Path $path } | Should -Throw
    }

    It 'throws when a node has no label key' {
      $yaml = @'
menu:
  title: "T"
  items:
    - exit: true
'@
      $path = New-TempMenuFile -Content $yaml
      { Read-MenuFile -Path $path } | Should -Throw
    }

    It 'throws when a node has no recognized type keys' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "Orphan"
      description: "I have no type"
'@
      $path = New-TempMenuFile -Content $yaml
      { Read-MenuFile -Path $path } | Should -Throw
    }
  }

  # ---------------------------------------------------------------------------
  Describe 'Read-MenuFile - node properties are correctly populated' {
    # ---------------------------------------------------------------------------

    It 'populates Label correctly' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "My Label"
      exit: true
'@
      $path = New-TempMenuFile -Content $yaml
      $result = Read-MenuFile -Path $path
      $result.Items[0].Label | Should -Be 'My Label'
    }

    It 'populates Description when present' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "Item"
      description: "Some detail"
      call: "Do-Thing"
'@
      $path = New-TempMenuFile -Content $yaml
      $result = Read-MenuFile -Path $path
      $result.Items[0].Description | Should -Be 'Some detail'
    }

    It 'Description is null when not specified' {
      $path = New-TempMenuFile -Content $script:SimpleMenuYaml
      $result = Read-MenuFile -Path $path
      $result.Items[0].Description | Should -BeNullOrEmpty
    }

    It 'populates Hotkey when present' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "Item"
      hotkey: "R"
      call: "Do-Thing"
'@
      $path = New-TempMenuFile -Content $yaml
      $result = Read-MenuFile -Path $path
      $result.Items[0].Hotkey | Should -Be 'R'
    }

    It 'Confirm is true when confirm: true is set' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "Dangerous"
      confirm: true
      call: "Do-Thing"
'@
      $path = New-TempMenuFile -Content $yaml
      $result = Read-MenuFile -Path $path
      $result.Items[0].Confirm | Should -BeTrue
    }

    It 'Confirm is false when confirm is not set' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "Safe"
      call: "Do-Thing"
'@
      $path = New-TempMenuFile -Content $yaml
      $result = Read-MenuFile -Path $path
      $result.Items[0].Confirm | Should -BeFalse
    }

    It 'Before array is populated from string shorthand' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "Guarded"
      before: "Assert-Session"
      call: "Do-Thing"
'@
      $path = New-TempMenuFile -Content $yaml
      $result = Read-MenuFile -Path $path
      $result.Items[0].Before.Count | Should -Be 1
      $result.Items[0].Before[0].Hook | Should -Be 'Assert-Session'
    }

    It 'Before array is populated from a single hook object' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "Guarded"
      before:
        hook: "Assert-Session"
        params:
          role: "admin"
      call: "Do-Thing"
'@
      $path = New-TempMenuFile -Content $yaml
      $result = Read-MenuFile -Path $path
      $result.Items[0].Before.Count       | Should -Be 1
      $result.Items[0].Before[0].Hook     | Should -Be 'Assert-Session'
      $result.Items[0].Before[0].Params['role'] | Should -Be 'admin'
    }

    It 'Before array is populated from a list of hook objects' {
      $yaml = @'
menu:
  title: "T"
  items:
    - label: "Guarded"
      before:
        - hook: "Assert-Auth"
        - hook: "Assert-Network"
          params:
            timeout: 5
      call: "Do-Thing"
'@
      $path = New-TempMenuFile -Content $yaml
      $result = Read-MenuFile -Path $path
      $result.Items[0].Before.Count | Should -Be 2
      $result.Items[0].Before[0].Hook | Should -Be 'Assert-Auth'
      $result.Items[0].Before[1].Hook | Should -Be 'Assert-Network'
    }

    It 'Before is an empty array when no before: key is present' {
      $path = New-TempMenuFile -Content $script:SimpleMenuYaml
      $result = Read-MenuFile -Path $path
      $result.Items[0].Before.Count | Should -Be 0
    }
  }

  # ---------------------------------------------------------------------------
  Describe 'Read-MenuFile - import cache' {
  # ---------------------------------------------------------------------------

    BeforeEach {
      $script:YamlTUI_ImportCache = @{}
    }

    It 'populates YamlTUI_ImportCache with the imported file path after first parse' {
      $subYaml = "items:`n  - label: CacheItem`n    exit: true"
      Set-Content -Path (Join-Path -Path $TestDrive -ChildPath 'cache.sub.yaml') -Value $subYaml -Encoding UTF8
      $rootYaml = @'
menu:
  title: "Cache Test"
  items:
    - label: "Branch"
      import: "./cache.sub.yaml"
    - label: "Exit"
      exit: true
'@
      $path = New-TempMenuFile -Content $rootYaml -FileName 'cache.root.yaml'
      Read-MenuFile -Path $path | Out-Null
      $script:YamlTUI_ImportCache.Count | Should -Be 1
    }

    It 'produces one cache entry when the same file is imported twice in the same tree' {
      $subYaml = "items:`n  - label: Shared`n    exit: true"
      Set-Content -Path (Join-Path -Path $TestDrive -ChildPath 'shared.sub.yaml') -Value $subYaml -Encoding UTF8
      $rootYaml = @'
menu:
  title: "Double Import"
  items:
    - label: "First"
      import: "./shared.sub.yaml"
    - label: "Second"
      import: "./shared.sub.yaml"
    - label: "Exit"
      exit: true
'@
      $path = New-TempMenuFile -Content $rootYaml -FileName 'double.root.yaml'
      $result = Read-MenuFile -Path $path
      # Both branches resolved correctly from cache
      $result.Items[0].Children[0].Label | Should -Be 'Shared'
      $result.Items[1].Children[0].Label | Should -Be 'Shared'
      # Only one cache entry despite two imports of the same file
      $script:YamlTUI_ImportCache.Count | Should -Be 1
    }

    It 'cache entry holds the resolved PSCustomObject array for the imported file' {
      $subYaml = "items:`n  - label: Cached`n    exit: true"
      Set-Content -Path (Join-Path -Path $TestDrive -ChildPath 'typed.sub.yaml') -Value $subYaml -Encoding UTF8
      $rootYaml = @'
menu:
  title: "T"
  items:
    - label: "Branch"
      import: "./typed.sub.yaml"
    - label: "Exit"
      exit: true
'@
      $path = New-TempMenuFile -Content $rootYaml -FileName 'typed.root.yaml'
      Read-MenuFile -Path $path | Out-Null
      $cachedItems = $script:YamlTUI_ImportCache.Values | Select-Object -First 1
      $cachedItems | Should -Not -BeNullOrEmpty
      $cachedItems[0].Label | Should -Be 'Cached'
    }
  }
}
