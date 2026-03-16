````markdown
# PSYamlTUI

YAML-powered recursive terminal UI menu system for PowerShell 5.1+.
Define deeply nested menus in YAML, launch with a single command.

---

## Project Status

- [x] Module scaffold
- [x] YamlDotNet.dll bundled
- [x] YAML parser + validation + token substitution
- [x] Terminal profile detection
- [x] Rendering engine (3 tiers)
- [x] Navigation + input handler
- [x] Action executor (script + function)
- [x] Import resolution (external submenu files)
- [x] Border styles (Single, Double, Rounded, Heavy, ASCII)
- [x] Key binding customization + validation
- [x] Breadcrumb navigation
- [x] Color theme customization
- [x] Status bar (connected user, session info, custom data)

---

## Key Decisions

- `YamlDotNet.dll` bundled in `lib/` -- no external dependencies, no `RequiredAssemblies` (causes double-load crash on every `Import-Module` including `-Force`)
- Node type is inferred from keys present, never declared explicitly
- Inference order: `exit` -> `children`/`import` -> `.ps1`/path chars -> function name
- `Left Arrow` / `Escape` = Back, `Right Arrow` / `Enter` = Select, `Q` = Quit, `H` = Home
- Three render tiers: ANSI+Unicode, Write-Host+Unicode, Write-Host+ASCII
- Unicode and ANSI capability detected independently -- a terminal can have one without the other
- Terminal profile detected once per `Start-Menu` call, cached in `$script:YamlTUI_TermProfile`
- Recursion IS the nav stack -- going back is just returning from the recursive function
- Root menu file has `menu:` wrapper; submenu files have `items:` key only
- `import:` paths are always relative to root `menu.yaml`, never absolute
- `Invoke-Expression` is never used under any circumstances -- always `&` call operator

---

## Architecture
```
PSYamlTUI/                          # repo root
+-- .build.ps1                      # Invoke-Build entry point (Local + Full build tasks)
+-- Install-Requirements.ps1        # install dev dependencies + YamlDotNet.dll
+-- menu.yaml                       # sample root menu file for dev testing
+-- README.md
+-- CLAUDE.md                       # project notes + architecture reference
|
+-- .github/
|   +-- copilot-instructions.md     # Copilot agent instructions
|
+-- Build/
|   +-- BuildFunctions.ps1          # build task definitions (CopyLibFiles, CompileModule, etc.)
|
+-- Dev/
|   +-- test.ps1                    # scratch dev/test script
|
+-- Docs/                           # generated docs output (platyPS)
|
+-- Output/
|   +-- PSYamlTUI/                  # compiled build output (git-ignored)
|       +-- PSYamlTUI.psd1
|       +-- PSYamlTUI.psm1          # compiled + YamlDotNet loader block injected at top
|       +-- lib/
|           +-- YamlDotNet.dll
|
+-- scripts/                        # sample scripts callable from menu.yaml for dev/demo
|   +-- Clear-TempFiles.ps1
|   +-- Get-ProcessReport.ps1
|   +-- Get-TempFiles.ps1
|   +-- Show-SystemInfo.ps1
|   +-- Test-NetworkPing.ps1
|
+-- Source/                         # module source (import this for dev)
|   +-- PSYamlTUI.psd1              # manifest -- no RequiredAssemblies
|   +-- PSYamlTUI.psm1              # dot-sources Private/ + Public/, loads YamlDotNet
|   +-- ModuleBuilder.ps1           # ModuleBuilder config (used by .build.ps1)
|   +-- lib/
|   |   +-- YamlDotNet.dll          # bundled, MIT licensed, guarded by AppDomain check
|   +-- Private/
|   |   +-- Read-MenuFile.ps1       # YAML parsing, validation, {{key}} token substitution
|   |   +-- Invoke-MenuAction.ps1   # safe script/function executor
|   |   +-- Get-TerminalProfile.ps1 # terminal capability detection
|   |   +-- Get-CharacterSet.ps1    # border char hashtable for chosen style
|   |   +-- Get-ColorTheme.ps1      # returns resolved color hashtable for chosen theme
|   |   +-- Show-MenuFrame.ps1      # rendering engine + navigation loop + key helpers
|   +-- Public/
|       +-- Start-Menu.ps1          # only exported function
|
+-- Tests/                          # Pester tests
```

---

## Start-Menu Parameters
```powershell
Start-Menu
    [-Path <string>]             # default: .\menu.yaml
    [-BorderStyle <string>]      # Single | Double | Rounded | Heavy | ASCII  (default: Single)
    [-KeyBindings <hashtable>]   # custom key map (see Navigation section)
    [-Theme <string>]            # named built-in theme OR path to a theme JSON file
    [-StatusData <hashtable>]    # optional key/value pairs shown in status bar above footer
```

---

## Navigation Keys

| Key                    | Action                        |
|------------------------|-------------------------------|
| UpArrow / DownArrow    | Navigate items                |
| Enter / RightArrow     | Select / drill into submenu   |
| LeftArrow / Escape     | Back one level                |
| Q                      | Quit                          |
| H                      | Home (jump to root menu)      |
| Home / End             | Jump to first / last item     |
| PageUp / PageDown      | Scroll long menus             |

### Default Key Binding Hashtable
```powershell
@{
    Up     = [System.ConsoleKey]::UpArrow
    Down   = [System.ConsoleKey]::DownArrow
    Select = [System.ConsoleKey]::Enter
    Back   = @([System.ConsoleKey]::Escape, 'B')  # array = multiple triggers
    Quit   = 'Q'
    Home   = 'H'
}
```

### Key Binding Internals

- `Resolve-KeyAction` maps a `ConsoleKeyInfo` to a named action (Up, Down, Select, Back, Quit, Home)
- `Assert-KeyBindings` validates the hashtable at startup -- checks for duplicate keys, unknown actions, invalid values
- Key bindings hashtable is passed from `Start-Menu` through every recursive `Show-MenuFrame` call
- Module-scoped signal flags: `$script:YamlTUI_Quit` and `$script:YamlTUI_Home`
- At root frame, `Home` is a no-op (resets index, re-renders) -- never triggers quit
- Footer text is generated dynamically from active bindings via `Get-FooterText`

---

## Color Themes

Themes control every color in the UI. Pass a named built-in theme or a path to a JSON file.

### Theme Hashtable Shape
```powershell
# All values are [System.ConsoleColor] names (strings)
@{
    # Border + chrome
    Border          = 'DarkCyan'
    Title           = 'White'
    Breadcrumb      = 'DarkGray'

    # Menu items
    ItemDefault     = ''
    ItemSelected    = 'Yellow'       # text color of highlighted item
    ItemHotkey      = 'DarkGray'     # hotkey character highlight
    ItemDescription = 'DarkGray'    # subtitle line under selected item

    # Status bar
    StatusLabel     = 'DarkGray'    # key name  e.g. "Connected As"
    StatusValue     = 'Cyan'        # value      e.g. "DOMAIN\user"

    # Footer
    FooterText      = 'DarkGray'    # separator/label text in footer
}
```

### ItemDefault Empty String Rule

`ItemDefault = ''` means no `-ForegroundColor` param at all -- use terminal default.
Never pass an empty string to `-ForegroundColor`. Pattern:
```powershell
if ($Theme.ItemDefault -ne '') {
    Write-Host -Object $text -ForegroundColor $Theme.ItemDefault
} else {
    Write-Host -Object $text
}
```

### Built-in Themes

| Name      | Description                          |
|-----------|--------------------------------------|
| Default   | Dark background, cyan accents        |
| Light     | Light terminal friendly              |
| Minimal   | No background highlights, text only  |
| Classic   | White/gray, no color accents         |

Any key omitted in a custom file falls back to the Default theme value -- partial overrides are fine.

---

## Status Bar

An optional section rendered between the menu items and the footer. Pass a hashtable of
label/value pairs to `-StatusData`. Useful for displaying session context, connected accounts,
environment names, API connection state, etc.
```powershell
Start-Menu -StatusData @{
    'Connected As' = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    'Environment'  = 'Production'
    'AWS Profile'  = $env:AWS_PROFILE
    'DB'           = 'Connected'
}
```

### Rendered Output
```
+==========================================+
|  Connected As  DOMAIN\jsmith             |
|  Environment   Production                |
|  AWS Profile   default                   |
|  DB            Connected                 |
+==========================================+
|  <- Back   H Home   Q Quit               |
+==========================================+
```

### Rules
- Status bar only renders if `-StatusData` is passed and has at least one entry
- Values are display-only -- never executed or parsed
- Long values are truncated to fit terminal width
- Colors controlled by `StatusLabel` and `StatusValue` theme keys
- Status data is static for the lifetime of the `Start-Menu` call -- evaluated once at call time

---

## Rendering Architecture

- Detect terminal capability ONCE per `Start-Menu` call via `Get-TerminalProfile`
- Cache result in `$script:YamlTUI_TermProfile`, `$script:YamlTUI_CharSet`, and `$script:YamlTUI_Theme`
- Terminal profile properties: `UseAnsi`, `UseUnicode`, `ColorMethod`, `Width`
- Unicode and ANSI are detected independently
- `$env:WT_SESSION` signals Windows Terminal -- grant both Unicode and ANSI
- When `WT_SESSION` is detected and codepage is not 65001, set `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`
  so all Unicode chars (not just the CP437 subset) render correctly via Write-Host
- Three rendering tiers:
  - Tier 3: ANSI + Unicode (`[Console]::Write` single call per frame -- bypasses OutputEncoding)
  - Tier 2: `Write-Host` + Unicode (color via `-ForegroundColor`)
  - Tier 1: `Write-Host` + ASCII (fallback, works everywhere)
- Always build the full frame as a single string before writing -- never write line by line
- Character set keys: TopLeft, TopRight, BottomLeft, BottomRight, Horizontal, Vertical, LeftT, RightT, Selected, Bullet, Arrow
- Border styles: Single (default), Double, Rounded, Heavy, ASCII
  Configured via `-BorderStyle` on `Start-Menu`, passed to `Get-CharacterSet -Style`

---

## YAML Schema

### Node Types (inferred, never declared)

| Keys Present                      | Node Type | Behavior                   |
|-----------------------------------|-----------|----------------------------|
| exit: true                        | EXIT      | Clean quit                 |
| children or import                | BRANCH    | Renders as submenu         |
| call with .ps1 or / or \          | SCRIPT    | Path-jailed & execution    |
| call with no extension/path chars | FUNCTION  | Get-Command whitelist + &  |

### Valid Node Properties

| Key         | Type   | Node Types  | Notes                                      |
|-------------|--------|-------------|--------------------------------------------|
| label       | string | all         | Required. Display text.                    |
| exit        | bool   | EXIT        | Signals clean quit.                        |
| children    | list   | BRANCH      | Inline submenu items.                      |
| import      | string | BRANCH      | Relative path to external yaml file.       |
| call        | string | SCRIPT/FUNC | Script path or PS function name.           |
| params      | map    | SCRIPT/FUNC | Splatted hashtable. Strings/bools/numbers. |
| confirm     | bool   | SCRIPT/FUNC | Prompts Y/N before executing.              |
| description | string | any         | Subtitle shown on selected item.           |
| hotkey      | string | any         | Single char shortcut. Case-insensitive.    |

### Validation Rules
- A node cannot have both `children` and `import`
- A node cannot have both `children`/`import` and `call`
- `params` values are strings, bools, or numbers only -- no nested objects
- `hotkey` is a single character only
- `import` paths must be relative -- absolute paths are rejected at parse time
- `call` values are validated at parse time before any menu renders
- `|`, `;`, `&`, `>` in `call` values are rejected (injection prevention)


---

## PS 5.1 Constraints

- No non-ASCII characters in string literals or throw statements (comments are fine)
- `Join-Path` accepts 2 args only -- chain calls for deeper paths
- Use `$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath()` for path resolution -- never `[System.IO.Path]::GetFullPath()` (uses .NET CWD, not PS CWD)
- Guard all `Add-Type` calls with an AppDomain check -- double-load throws a terminating error that is not catchable via `-ErrorAction`
- `RequiredAssemblies` in psd1 fires on every `Import-Module` including `-Force` -- causes double-load crash. Do NOT use it. The build pipeline injects the loader block instead.
- Import `platyPS` and `Pester` lazily inside build tasks only -- never at module top level (`#Requires -Module platyPS` at script top loads platyPS, which bundles its own YamlDotNet, before any task runs)

---

## Dev Bootstrap
```powershell
# dot-source to load dev environment
Push-Location C:\path\to\PSYamlTUI
Import-Module .\Source\PSYamlTUI.psd1 -Force

function menu {
    Start-Menu -BorderStyle Rounded -StatusData @{
        'Connected As' = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    }
}

Write-Host "PSYamlTUI loaded. Type 'menu' to launch." -ForegroundColor Cyan
```
```powershell
. .\dev.ps1   # load
menu          # launch
. .\dev.ps1   # reload after edits
```

---

## Code Style & Formatting

### Character Safety (PS 5.1)
- ASCII only in ALL string literals, error messages, throw statements, and Write-* calls
- No em dashes (--), smart quotes, ellipsis (...), or any Unicode > 127 in code
- Unicode characters are allowed in comments only
- If you want a dash in a string use a plain hyphen (-)
- If you want an ellipsis in a string use three dots (...)

### Naming Conventions
- Functions: Verb-Noun format, approved verbs only (Get-Verb for the list)
- Parameters: PascalCase
- Local variables: camelCase
- Script-scoped variables: $script:PascalCase
- Constants: ALL_CAPS is NOT a PowerShell convention -- use $script:PascalCase
- Private functions: no special prefix needed, just not exported in manifest

### Function Structure
- Always [CmdletBinding()] on every function, public and private
- Always explicit param() block with types on every parameter
- Always specify OutputType where the return type is known
- Parameter validation attributes preferred over manual checks:
    [ValidateNotNullOrEmpty()]
    [ValidateSet('Option1','Option2')]
    [ValidateRange(1,100)]
    [ValidatePattern('^[a-zA-Z]+$')]

### General Rules
- Never use aliases in module code (% gci ? foreach where)
  Always spell out: ForEach-Object, Get-ChildItem, Where-Object
- Never use positional parameters in module code -- always named
  Bad:  Get-ChildItem C:\temp
  Good: Get-ChildItem -Path C:\temp
- Prefer $null -eq $var over $var -eq $null (avoids accidental array comparison)
- Prefer -eq $false over -not where clarity matters
- Single quotes for strings that dont need interpolation
- Double quotes only when the string contains variables or escape sequences
- No semicolons to chain statements -- use separate lines
- One logical concept per line
- Explicit return statements in functions that return values
- Never suppress errors silently with -ErrorAction SilentlyContinue
  unless the absence of a result is the expected/handled case

### Comments
- XML doc comments on all public functions:
    <#
    .SYNOPSIS
    .DESCRIPTION
    .PARAMETER
    .EXAMPLE
    #>
- Inline comments explain WHY not WHAT
- No redundant comments: # increment counter  $i++  -- never do this
- Em dashes and Unicode are fine in comments

### Error Handling
- Use terminating errors (throw / Write-Error -ErrorAction Stop) for unrecoverable states
- Use non-terminating Write-Error for recoverable/warning states
- Always include a meaningful message -- never throw $_.Exception alone
- Catch specific exception types where possible, not bare catch {}

### Performance
- Avoid appending to arrays in loops -- use [System.Collections.Generic.List[object]]
- Avoid repeated property lookups in tight loops -- cache in a local variable
- Prefer pipeline where it reads naturally
- Avoid Where-Object in hot paths -- use if() inside ForEach-Object or a for loop
- Use [System.Text.StringBuilder] for string concatenation in loops

## Before Hooks

### Purpose
Before hooks are the ONLY hook type in PSYamlTUI. There is no after hook.
Hooks are a pre-execution concern only -- "is it safe/valid to proceed?"
Post-execution logic belongs inside the called script or function, not the menu layer.

### What Hooks Are For
- Authentication checks + inline re-authentication prompts
- Permission / role validation
- Environment or network reachability checks
- Any gate that should block execution if not met

### Schema

# Shorthand -- single hook, no params
before: "Assert-ApiSession"

# Single hook with params
before:
  hook: "Assert-ApiSession"
  params:
    role: "admin"
    tenant: "{{environment}}"

# Multiple hooks
before:
  - hook: "Assert-ApiSession"
    params:
      role: "admin"
  - hook: "Assert-NetworkAccess"
    params:
      target: "prod-cluster"
      timeout: 30

### Hook Object Shape
- hook    string   required   PS function name only -- no path chars, no extension
- params  map      optional   Strings, bools, numbers only -- no nested objects
                              Token substitution ({{key}}) works in param values

### Valid On
- LEAF nodes   (before the call executes)
- BRANCH nodes (before the submenu renders -- useful for auth-gating entire sections)

### Inheritance
- before: defined on a BRANCH node is inherited by ALL descendant nodes
- Hooks are collected walking from root to current node, outermost first
- Node-level before: hooks run AFTER inherited hooks
- A node can define before: on top of an inherited hook -- they stack, not replace

### Execution Order
1. Collect inherited hooks (root -> current node, outermost first)
2. Collect node-level hooks
3. Run all hooks in order via Invoke-BeforeHook
4. Any hook returns $false  -> abort silently, return to menu, no error displayed
5. Any hook throws           -> abort, display exception message, return to menu
6. All hooks return $true   -> proceed to confirm prompt if needed, then execute call

### Hook Function Contract
- Must return $true or $false
- May throw to abort with a message
- May prompt the user inline (credentials, confirmation, input)
- May update $script:YamlTUI_StatusData to refresh status bar values
- Must NOT assume pipeline output is consumed -- return explicit bool only
- Must be a named PS function (Get-Command whitelisted) -- anonymous scriptblocks not supported

### Invoke-BeforeHook Behavior
- Normalizes string shorthand and full hook object to same internal shape
- Validates function exists via Get-Command -CommandType Function before calling
- Rejects hook names containing path chars or extensions (same rules as call nodes)
- Calls [Console]::Clear() before running hook so prompts appear on clean screen
- Menu re-renders naturally when Show-MenuFrame resumes after hook returns
- Uses & call operator always -- never Invoke-Expression

### Validation at Parse Time
- hook name must pass same injection checks as call values
- hook name must contain no path separators or file extensions
- params values must be strings, bools, or numbers -- no nested objects
- token substitution applied to params values before execution (not at parse time)

### What Hooks Are NOT For
- Post-execution logic               -- handle inside your script/function
- Conditional branching of call path -- handle inside your script/function
- Return value processing            -- handle inside your script/function
- Logging completed actions          -- handle inside your script/function
  (though a before: hook could log intent before execution if needed)

### Example -- Auth gating an entire submenu section
items:
  - label: "Cloud Accounts"
    before:
      hook: "Assert-ApiSession"
      params:
        tenant: "{{environment}}"
    children:
      - label: "Create Cloud2 Account"
        call: "./scripts/New-Account.ps1"
        params:
          type: "cloud2"

      - label: "Delete Account"
        before:
          hook: "Assert-ApiSession"
          params:
            role: "admin"
        confirm: true
        call: "./scripts/Remove-Account.ps1"

### Example -- Hook function implementation pattern
function Assert-ApiSession {
    param(
        [string]$Role = 'User',
        [string]$Tenant = 'default'
    )

    # Already authenticated -- proceed immediately
    if ($script:ApiSession -and $script:ApiSession.IsValid) {
        return $true
    }

    # Not authenticated -- prompt inline
    $credential = Get-Credential -Message "Enter credentials for $Tenant"
    if ($null -eq $credential) { return $false }

    try {
        $script:ApiSession = Connect-MyApi -Credential $credential -Tenant $Tenant -Role $Role
        $script:YamlTUI_StatusData['Connected As'] = $script:ApiSession.Username
        $script:YamlTUI_StatusData['Tenant']        = $Tenant
        return $true
    }
    catch {
        Write-Host "Authentication failed: $_" -ForegroundColor Red
        return $false
    }
}

## Token Substitution

### Removed: -SettingsPath / settings.json
settings.json is removed and must not be reintroduced. JSON requires \\ for Windows
paths and YAML special characters in JSON values cause silent YAML corruption that is
very hard to trace. Replaced entirely by vars.yaml + -Context.

### vars.yaml
Companion file for static values reused across the menu tree. Sits next to menu.yaml.
Auto-discovered by name -- no parameter needed in the simple case.
Override with -VarsPath for environment switching.
```yaml
# vars.yaml
vars:
  scriptsPath: "./scripts"
  environment: "prod"
  region:      "us-east-1"
  apiBase:     "https://api.internal.com"
  appName:     "MyApp"
```

Windows paths are safe -- YAML does not require backslash escaping:
```yaml
vars:
  scriptsPath: "C:\scripts\myapp"    # works as-is, no \\ needed
```

### -Context Hashtable
Runtime values computed at launch time -- things only known when the menu is invoked.
Merged over vars.yaml values. -Context wins on any key conflict.
```powershell
Start-Menu -VarsPath ./production.vars.yaml -Context @{
    currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    sessionId   = $script:ApiSession.Id
}
```

### vars.yaml vs -Context
```
vars.yaml / -VarsPath   static, file-based, checked into source control
                        scriptsPath, apiBase, appName, environment name

-Context                dynamic, runtime, computed at launch time
                        current username, session tokens, live env var values
```

### Environment Switching Pattern
```
menu.yaml
vars.yaml                   # default/dev, auto-discovered
production.vars.yaml
staging.vars.yaml
```
```powershell
Start-Menu                                         # dev, picks up vars.yaml
Start-Menu -VarsPath ./production.vars.yaml        # production
Start-Menu -VarsPath ./staging.vars.yaml           # staging
```

### Substitution Rules
- Tokens are {{key}} -- double curly braces, no spaces
- Applied to the raw YAML string before parsing
- Works in: label, description, call, import, params values, before.params values
- Unknown tokens are left as-is -- no error thrown
- -Context values override vars.yaml on key conflict
- Tokens in import: paths resolve before the imported file is loaded

### Updated Start-Menu Parameters
```powershell
Start-Menu
    [-Path <string>]             # default: .\menu.yaml
    [-VarsPath <string>]         # default: .\vars.yaml if present, optional otherwise
    [-Context <hashtable>]       # runtime values, merged over vars.yaml
    [-BorderStyle <string>]      # Single | Double | Rounded | Heavy | ASCII
    [-Theme <string>]            # named theme or path to theme YAML file
    [-KeyBindings <hashtable>]   # custom key map
    [-StatusData <hashtable>]    # key/value pairs shown in status bar
```

## Task: Write Comprehensive Pester Tests for PSYamlTUI

Write a complete Pester 5 test suite for the PSYamlTUI PowerShell module.
Tests must run on both PowerShell 5.1 and PowerShell 7+.

---

### Test Project Structure
```
Tests/
+-- Unit/
|   +-- Read-MenuFile.Tests.ps1
|   +-- Invoke-MenuAction.Tests.ps1
|   +-- Invoke-BeforeHook.Tests.ps1
|   +-- Get-TerminalProfile.Tests.ps1
|   +-- Get-CharacterSet.Tests.ps1
|   +-- Get-ColorTheme.Tests.ps1
|   +-- Resolve-TokenContext.Tests.ps1
+-- Integration/
|   +-- Navigation.Tests.ps1
|   +-- HookInheritance.Tests.ps1
|   +-- TokenSubstitution.Tests.ps1
+-- Fixtures/
|   +-- menus/
|   |   +-- simple.menu.yaml
|   |   +-- nested.menu.yaml
|   |   +-- hooks.menu.yaml
|   |   +-- tokens.menu.yaml
|   |   +-- invalid.menu.yaml
|   +-- vars/
|   |   +-- simple.vars.yaml
|   |   +-- windows-paths.vars.yaml
|   +-- themes/
|       +-- partial.theme.yaml
+-- PSYamlTUI.Tests.ps1      # test suite entry point
```

---

### General Rules for All Tests

- Use Pester 5 syntax only -- no Pester 4 Should -Be style without -ActualValue
- Always use BeforeAll / BeforeEach / AfterAll / AfterEach for setup and teardown
- Never rely on global state leaking between tests -- each Describe block is isolated
- Mock all console output in unit tests -- never let Write-Host or [Console]::Write
  actually print during test runs
- Mock [Console]::ReadKey for any test that touches navigation or key input
- Use InModuleScope PSYamlTUI for testing private functions
- Never test implementation details -- test behavior and outcomes
- Each It block tests exactly one thing
- It block descriptions read as plain English sentences describing expected behavior
- No magic numbers or hardcoded paths -- use $TestDrive for temp files

---

### Read-MenuFile.Tests.ps1

Test all of the following behaviors:

YAML LOADING
- Loads a valid root menu.yaml and returns a parsed object
- Loads a submenu file referenced via import: key
- Resolves nested import chains (import inside an imported file)
- Throws a descriptive error when the file does not exist
- Throws a descriptive error when the YAML is malformed
- Handles empty children: list without error

NODE TYPE INFERENCE
- Infers EXIT node when exit: true is present
- Infers BRANCH node when children: key is present
- Infers BRANCH node when import: key is present
- Infers SCRIPT node when call: ends in .ps1
- Infers SCRIPT node when call: contains forward slash
- Infers SCRIPT node when call: contains backslash
- Infers FUNCTION node when call: has no extension and no path chars
- Does not infer SCRIPT when call: is a plain function name with no dots

VALIDATION -- should throw or return error for each:
- Node with both children: and import:
- Node with both children: and call:
- Node with both import: and call:
- import: path that is absolute (C:\ or /)
- call: value containing pipe character |
- call: value containing semicolon ;
- call: value containing ampersand &
- call: value containing redirect >
- hotkey: value longer than one character
- params: value that is a nested object
- hook: name containing a path separator
- hook: name containing a file extension

---

### Resolve-TokenContext.Tests.ps1

- Returns empty hashtable when no vars file exists and no context passed
- Loads vars.yaml from same directory as menu.yaml when present
- Loads vars file from -VarsPath when specified
- Merges -Context hashtable over vars.yaml values
- -Context value wins when same key exists in both vars.yaml and -Context
- Leaves unknown {{tokens}} as-is in output -- does not throw
- Substitutes {{token}} in label values
- Substitutes {{token}} in call values
- Substitutes {{token}} in import: paths
- Substitutes {{token}} in params values
- Substitutes {{token}} in before.params values
- Substitutes {{token}} in description values
- Does not substitute inside YAML keys -- only values
- Windows paths in vars.yaml substitute correctly without double-backslash
- Handles vars.yaml with no vars: key gracefully

---

### Invoke-BeforeHook.Tests.ps1

- Accepts plain string shorthand and normalizes to hook object internally
- Accepts single hook object with params
- Accepts list of hook objects and runs them in order
- Returns $true when hook function returns $true
- Returns $false when hook function returns $false
- Catches thrown exception and returns $false with message
- Throws descriptive error when hook function does not exist
- Throws descriptive error when hook name contains a path separator
- Throws descriptive error when hook name contains a file extension
- Passes params to hook function via splatting
- Passes empty hashtable when no params defined on hook
- Runs inherited hooks before node-level hooks
- Runs all hooks in order -- outermost inherited first
- Stops executing remaining hooks when one returns $false
- Calls [Console]::Clear() before invoking hook function
- Uses & call operator -- never Invoke-Expression
- Validates hook function via Get-Command -CommandType Function

---

### Invoke-MenuAction.Tests.ps1

- Executes a .ps1 script file via & operator
- Passes params to script via splatting
- Executes a PowerShell function via & operator
- Passes params to function via splatting
- Canonicalizes relative script paths before execution
- Rejects script path that escapes root jail via path traversal (../../evil.ps1)
- Rejects script path that is absolute
- Validates function exists via Get-Command before calling
- Throws descriptive error when script file does not exist
- Throws descriptive error when function does not exist
- Never calls Invoke-Expression under any circumstances
- Runs before hooks before executing call
- Aborts execution silently when before hook returns $false
- Displays error message when before hook throws
- Shows confirm prompt when confirm: true on node
- Executes call when user confirms Y
- Aborts silently when user confirms N

---

### Get-TerminalProfile.Tests.ps1

- Returns hashtable with keys: UseAnsi, UseUnicode, ColorMethod, Width
- Sets UseUnicode = $true when $env:WT_SESSION is set
- Sets UseAnsi = $true when $env:WT_SESSION is set
- Sets UseUnicode = $true when OutputEncoding.CodePage is 65001
- Sets UseUnicode = $false when PS version is 5.1 and WT_SESSION not set
- Sets ColorMethod = 'Ansi' when UseAnsi is $true
- Sets ColorMethod = 'WriteHost' when UseAnsi is $false
- Sets OutputEncoding to UTF8 when WT_SESSION present and CodePage != 65001
- Width matches [Console]::WindowWidth
- MENU_CHARSET env var override to ASCII forces UseUnicode = $false
- MENU_CHARSET env var override to UNICODE forces UseUnicode = $true
- Detects VS Code terminal via TERM_PROGRAM env var
- Detects xterm-compatible terminals via TERM env var

---

### Get-CharacterSet.Tests.ps1

- Returns hashtable with all required keys:
  TopLeft, TopRight, BottomLeft, BottomRight, Horizontal, Vertical,
  LeftT, RightT, Selected, Bullet, Arrow
- Single style returns correct box-drawing characters
- Double style returns correct box-drawing characters
- Rounded style returns correct box-drawing characters
- Heavy style returns correct box-drawing characters
- ASCII style returns only ASCII characters (all values are ASCII 0-127)
- Throws descriptive error for unknown style name
- All Unicode styles return characters that are valid Unicode

---

### Get-ColorTheme.Tests.ps1

- Returns hashtable with all required color keys for Default theme
- All values in Default theme are valid [System.ConsoleColor] names
- Named theme Light returns valid color hashtable
- Named theme Minimal returns valid color hashtable
- Named theme Classic returns valid color hashtable
- Throws descriptive error for unknown theme name
- Loads custom theme from YAML file
- Custom theme partial override -- missing keys fall back to Default values
- Custom theme full override -- all keys present, no fallback needed
- Throws descriptive error when theme file does not exist
- Throws descriptive error when theme file contains invalid ConsoleColor value

---

### Integration: TokenSubstitution.Tests.ps1

- Full menu.yaml with vars.yaml loads and substitutes all tokens correctly
- Token in call: path resolves to correct script path after substitution
- Token in import: path loads correct submenu file
- Token in label renders correctly in parsed node
- Token in before.params passes correct value to hook
- -Context value overrides vars.yaml value for same key
- Menu with no vars.yaml and no -Context loads without error
- Unknown token left as-is in parsed node value

---

### Integration: HookInheritance.Tests.ps1

- Branch node before: hook runs when child leaf node is executed
- Branch node before: hook runs when entering child submenu
- Child node before: hook runs after parent branch hook
- Two levels of branch inheritance -- grandparent hook runs first
- Node-level hook runs after all inherited hooks
- Inherited hook returning $false blocks child execution
- Inherited hook throwing blocks child execution with error message
- Hook params are scoped to their own hook -- not shared between hooks in chain

---

### Fixtures

Create the following YAML fixture files for use across tests.
Place in Tests/Fixtures/
```yaml
# Fixtures/menus/simple.menu.yaml
menu:
  title: "Test Menu"
  items:
    - label: "Action One"
      call: "./scripts/action-one.ps1"
    - label: "Function One"
      call: "Invoke-TestFunction"
    - label: "Exit"
      exit: true
```
```yaml
# Fixtures/menus/nested.menu.yaml
menu:
  title: "Nested Menu"
  items:
    - label: "Level One"
      children:
        - label: "Level Two"
          children:
            - label: "Deep Action"
              call: "./scripts/deep.ps1"
        - label: "Level Two Action"
          call: "./scripts/l2.ps1"
    - label: "Exit"
      exit: true
```
```yaml
# Fixtures/menus/hooks.menu.yaml
menu:
  title: "Hooks Menu"
  items:
    - label: "Gated Section"
      before:
        hook: "Test-BranchHook"
        params:
          role: "admin"
      children:
        - label: "Gated Action"
          before: "Test-LeafHook"
          call: "./scripts/gated.ps1"
    - label: "Exit"
      exit: true
```
```yaml
# Fixtures/menus/tokens.menu.yaml
menu:
  title: "{{appName}}"
  items:
    - label: "Deploy to {{environment}}"
      call: "{{scriptsPath}}/deploy.ps1"
      params:
        env: "{{environment}}"
    - label: "Exit"
      exit: true
```
```yaml
# Fixtures/vars/simple.vars.yaml
vars:
  appName:     "TestApp"
  environment: "test"
  scriptsPath: "./scripts"
```
```yaml
# Fixtures/vars/windows-paths.vars.yaml
vars:
  scriptsPath: "C:\scripts\myapp"
  logPath:     "C:\logs\myapp"
```

---

### Test Coverage Targets

- Unit test coverage: all private functions fully covered
- Every validation rule in Read-MenuFile has a dedicated negative test
- Every security constraint (no IEX, path jail, injection chars) has a dedicated test
- No test should touch the real filesystem except via $TestDrive
- No test should produce visible console output during a clean run
- All tests pass on PS 5.1 and PS 7+ without modification

````