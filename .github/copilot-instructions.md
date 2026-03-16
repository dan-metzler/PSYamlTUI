````markdown
<!-- Last updated: 2026-03-15 -- reflects implemented state of PSYamlTUI -->
# PSYamlTUI -- Copilot Instructions

I am building a PowerShell module called PSYamlTUI.

The module builds fully recursive, YAML-driven terminal user interfaces from a single YAML file.
Here is the core architecture and constraints you must always follow.

---

## Build & Dev Commands
```powershell
# Install dev dependencies + YamlDotNet.dll
.\Install-Requirements.ps1

# Run from source (no build needed, picks up edits immediately)
Import-Module .\Source\PSYamlTUI.psd1 -Force
Start-Menu

# Local build (compile + copy lib + import)
Invoke-Build -Type Local

# Full build (git check + compile + docs + tests)
Invoke-Build -Type Full
```

Build output lands in `Output\PSYamlTUI\`. The `CopyLibFiles` build task injects a YamlDotNet
AppDomain-guard loader block at the top of the compiled psm1 (ModuleBuilder strips the source
psm1 header, so this injection is the only way the DLL loads in the built output).

---

## Module Structure
````
PSYamlTUI/                          # repo root
+-- .build.ps1                      # Invoke-Build entry point (Local + Full build tasks)
+-- Install-Requirements.ps1        # install dev dependencies + YamlDotNet.dll
+-- menu.yaml                       # sample root menu file for dev testing
+-- README.md
+-- CLAUDE.md                       # project notes + architecture reference
|
+-- .github/
|   +-- copilot-instructions.md     # Copilot agent instructions (this file)
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
|   +-- PSYamlTUI.psd1              # manifest -- no RequiredAssemblies (causes double-load crash)
|   +-- PSYamlTUI.psm1              # dev entry: dot-sources Private/ and Public/, loads YamlDotNet
|   +-- ModuleBuilder.ps1           # ModuleBuilder config (used by .build.ps1)
|   +-- lib/
|   |   +-- YamlDotNet.dll          # bundled; never loaded via RequiredAssemblies
|   +-- Private/
|   |   +-- Read-MenuFile.ps1       # YAML parsing, validation, {{key}} token substitution
|   |   +-- Invoke-MenuAction.ps1   # safe script/function executor
|   |   +-- Get-TerminalProfile.ps1 # terminal capability detection (once per Start-Menu call)
|   |   +-- Get-CharacterSet.ps1    # returns border char hashtable for the chosen style
|   |   +-- Get-ColorTheme.ps1      # merges user theme with defaults, returns 10-key hashtable
|   |   +-- Show-MenuFrame.ps1      # rendering engine + navigation loop + key binding helpers
|   +-- Public/
|       +-- Start-Menu.ps1          # only exported function
|
+-- Tests/                          # Pester tests
````

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

## Compatibility

- Must support PowerShell 5.1 and PS7+
- YamlDotNet 16.x DLL is bundled in `Source/lib/` (no external dependencies at runtime)
- Never use features that break PS 5.1 unless wrapped in a version check

### PS 5.1 Pitfalls (hard-won lessons)

- **Unicode in string literals / throw statements**: PS 5.1 reads .ps1 as ANSI by default.
  Em dashes, smart quotes, and any non-ASCII character inside a string literal causes
  a parse error. Safe in comments only. Use plain ASCII in all strings.
- **`Join-Path` only supports 2 args**: use `Join-Path (Join-Path $a $b) $c`
- **CWD mismatch**: `[System.IO.Path]::GetFullPath()` uses .NET CWD, not PS CWD.
  Always use: `$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($path)`
- **`Add-Type` assembly already loaded**: throws a terminating error (not catchable via
  `-ErrorAction`). Always guard with AppDomain check before calling `Add-Type`.
- **`RequiredAssemblies` in psd1**: fires on every `Import-Module` including `-Force`.
  Causes double-load crash. Do NOT use it. The build pipeline injects the loader instead.
- **`#Requires -Module platyPS`** at script top loads platyPS (which bundles its own
  YamlDotNet) before any task runs. Import platyPS and Pester lazily inside their tasks only.

---

## Security

- Never use `Invoke-Expression` under any circumstances
- Always use the `&` call operator for script and function execution
- Always canonicalize and root-jail file paths before execution
- Validate all param keys/values before passing to called scripts/functions
- Whitelist function names via `Get-Command` before calling
- Reject pipeline/shell operators (`|`, `;`, `&`, `>`) in `call` values at parse time

---

## Rendering Architecture

- Detect terminal capability ONCE per `Start-Menu` call via `Get-TerminalProfile`
- Cache result in `$script:YamlTUI_TermProfile`, `$script:YamlTUI_CharSet`, and `$script:YamlTUI_Theme`
- Terminal profile: `UseAnsi`, `UseUnicode`, `ColorMethod`, `Width`
- Unicode and ANSI are detected independently
- `$env:WT_SESSION` signals Windows Terminal -- grant both Unicode and ANSI
- When WT_SESSION is detected and codepage != 65001, set `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`
  so all Unicode chars (not just CP437 subset) render correctly via Write-Host
- Three rendering tiers:
  - Tier 3: ANSI + Unicode (`[Console]::Write` single call per frame -- bypasses OutputEncoding)
  - Tier 2: `Write-Host` + Unicode (color via `-ForegroundColor`)
  - Tier 1: `Write-Host` + ASCII (fallback, works everywhere)
- Always build the full frame as a single string before writing -- never write line by line
- Character set keys: TopLeft, TopRight, BottomLeft, BottomRight, Horizontal, Vertical,
  LeftT, RightT, Selected, Bullet, Arrow
- Border styles: Single (default), Double, Rounded, Heavy, ASCII
  Configured via `-BorderStyle` on `Start-Menu`, passed to `Get-CharacterSet -Style`

---

## Navigation

- Recursion IS the navigation stack -- going back is just returning from the function
- Breadcrumb array passed down with each recursive call
- Key bindings are a hashtable passed from `Start-Menu` through every recursive `Show-MenuFrame` call
- `Resolve-KeyAction` maps a `ConsoleKeyInfo` to a named action
- `Assert-KeyBindings` validates the hashtable at startup (duplicate keys, unknown actions, etc.)
- Named actions: `Up`, `Down`, `Select`, `Back`, `Quit`, `Home`
- Module-scoped signal flags: `$script:YamlTUI_Quit`, `$script:YamlTUI_Home`
- At root frame, `Home` is a no-op (resets index, re-renders) -- never triggers quit
- Footer text is generated dynamically from active bindings via `Get-FooterText`

### Default Key Bindings
```powershell
@{
    Up     = [System.ConsoleKey]::UpArrow
    Down   = [System.ConsoleKey]::DownArrow
    Select = [System.ConsoleKey]::Enter
    Back   = @([System.ConsoleKey]::Escape, 'B')   # array = multiple triggers
    Quit   = 'Q'
    Home   = 'H'
}
```

---

## YAML Schema

### File Structure
- Root file is always `menu.yaml` with a top-level `menu` key
- Submenu files have a top-level `items` key only, no `menu` wrapper
- Submenu files are referenced from any node via `import` key
- Import paths are always relative to the root `menu.yaml` location

### Node Types (inferred from keys present, never declared)
Check in this order:

1. `exit: true` => EXIT node
2. `children` or `import` => BRANCH node
3. `call` ending in `.ps1` or containing `/` or `\` => SCRIPT node
4. `call` with no extension and no path chars => FUNCTION node

### Valid Node Properties

| Key         | Type    | Required | Node types  | Notes                                      |
|-------------|---------|----------|-------------|--------------------------------------------|
| label       | string  | yes      | all         | Display text                               |
| exit        | bool    | no       | EXIT        | Signals clean quit                         |
| children    | list    | no       | BRANCH      | Inline submenu items                       |
| import      | string  | no       | BRANCH      | Path to external yaml file (relative only) |
| call        | string  | no       | SCRIPT/FUNC | Script path or function name               |
| params      | map     | no       | SCRIPT/FUNC | Passed as splatted hashtable               |
| confirm     | bool    | no       | SCRIPT/FUNC | Prompts Y/N before executing               |
| description | string  | no       | any         | Shown as subtitle on selected item         |
| hotkey      | string  | no       | any         | Single char shortcut                       |

### Rules
- A node CANNOT have both `children` and `import`
- A node CANNOT have both `children`/`import` and `call`
- `params` values are strings, bools, or numbers only -- no nested objects
- `hotkey` is a single character only, case-insensitive
- `import` paths are always relative, never absolute -- enforced at parse time
- `call` values are validated at parse time before any menu is displayed
- `|`, `;`, `&`, `>` in `call` values are rejected at parse time (injection prevention)

### Example
```yaml
menu:
  title: "Main Menu"
  items:
    - label: "Accounts"
      import: "./menus/accounts.yaml"

    - label: "Run Report"
      description: "Generates daily report"
      confirm: true
      hotkey: "R"
      call: "./scripts/New-Report.ps1"
      params:
        env: "{{environment}}"

    - label: "List Users"
      call: "Get-UserList"
      params:
        format: "table"

    - label: "Exit"
      exit: true
```

---

## Start-Menu Parameters
```powershell
Start-Menu
    [-Path <string>]             # default: .\menu.yaml
    [-BorderStyle <string>]      # Single|Double|Rounded|Heavy|ASCII  (default: Single)
    [-KeyBindings <hashtable>]   # custom key map (see Navigation section)
    [-Theme <string>]            # named built-in theme OR path to a theme JSON file
    [-StatusData <hashtable>]    # optional key/value pairs shown in status bar above footer
```

---

## Color Themes

- `Get-ColorTheme` merges a partial or full user-supplied theme with the Default theme
- Always returns a complete 10-key hashtable -- partial overrides are safe
- Named built-in themes: Default, Light, Minimal, Classic
- Pass a file path to load a JSON theme file; missing keys fall back to Default
- Result cached in `$script:YamlTUI_Theme` and passed to every `Show-MenuFrame` call

### Theme Hashtable Keys
```powershell
@{
    Border          = 'DarkCyan'   # box-drawing characters + frame
    Title           = 'White'      # menu title
    Breadcrumb      = 'DarkGray'   # breadcrumb trail
    ItemDefault     = ''           # unselected items -- empty string = no color (terminal default)
    ItemSelected    = 'Yellow'     # highlighted item
    ItemHotkey      = 'DarkGray'   # hotkey character
    ItemDescription = 'DarkGray'   # subtitle line under selected item
    StatusLabel     = 'DarkGray'   # status bar key names
    StatusValue     = 'Cyan'       # status bar values
    FooterText      = 'DarkGray'   # footer separator/label text
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

---

## Status Bar

- Rendered between menu items and footer when `-StatusData` is passed with at least one entry
- Pass a hashtable of label/value pairs; values are display-only, never executed
- Long values are truncated to fit terminal width
- Colors controlled by `StatusLabel` and `StatusValue` theme keys
- Static for the lifetime of the `Start-Menu` call -- evaluated once at call time
```powershell
Start-Menu -StatusData @{
    'Connected As' = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    'Environment'  = 'Production'
}
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

````