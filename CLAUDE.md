# PSYamlTUI

YAML-powered recursive terminal UI menu system for PowerShell 5.1+.

---

## Removed Features

- **-SettingsPath / settings.json** -- removed, do not reintroduce. JSON requires `\\` for Windows
  paths and YAML special chars in JSON values cause silent corruption. Replaced by vars.yaml + -Context.

---

## Key Decisions

- `YamlDotNet.dll` bundled in `lib/` -- no `RequiredAssemblies` in psd1 (causes double-load crash on every `Import-Module` including `-Force`)
- Node type is inferred from keys present, never declared explicitly
- Inference order: `exit` -> `children`/`import` -> `.ps1`/path chars -> function name
- Recursion IS the nav stack -- going back is just returning from the recursive function
- Root menu file has `menu:` wrapper; submenu files have `items:` key only
- `import:` paths are always relative to root `menu.yaml`, never absolute
- Before hooks are the ONLY hook type -- there is no after hook
- `Invoke-Expression` is never used under any circumstances -- always `&` call operator
- Terminal profile detected once per `Start-Menu` call, cached in `$script:YamlTUI_TermProfile`

---

## PS 5.1 Constraints

- No non-ASCII characters in string literals, throw statements, or Write-* calls (comments are fine)
- `Join-Path` accepts 2 args only -- chain calls for deeper paths
- Use `$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath()` for path resolution -- never `[System.IO.Path]::GetFullPath()` (uses .NET CWD, not PS CWD)
- Guard all `Add-Type` calls with an AppDomain check -- double-load throws a terminating error that is not catchable via `-ErrorAction`
- Import `platyPS` and `Pester` lazily inside build tasks only -- never at module top level

---

## Code Style

- Always `[CmdletBinding()]` on every function, public and private
- Always explicit `param()` block with types on every parameter
- Always specify `OutputType` where the return type is known
- Never use aliases -- always full cmdlet names
- Never use positional parameters -- always named
- Prefer `$null -eq $var` over `$var -eq $null`
- Single quotes for strings that need no interpolation; double quotes only when interpolating
- No semicolons to chain statements -- use separate lines
- Explicit `return` in functions that return values
- Never suppress errors silently with `-ErrorAction SilentlyContinue` unless absence of result is the expected case
- XML doc comments on all public functions (.SYNOPSIS .DESCRIPTION .PARAMETER .EXAMPLE)
- Inline comments explain WHY not WHAT
- Avoid appending to arrays in loops -- use `[System.Collections.Generic.List[object]]`
- Use `[System.Text.StringBuilder]` for string concatenation in loops

---

## YAML Validation Rules

- A node cannot have both `children` and `import`
- A node cannot have both `children`/`import` and `call`
- `params` values are strings, bools, or numbers only -- no nested objects
- `hotkey` is a single character only
- `import` paths must be relative -- absolute paths rejected at parse time
- `|`, `;`, `&`, `>` in `call` or `hook` values rejected at parse time
- `hook` names must have no path separators and no file extensions

---

## Gotchas

### ItemDefault Empty String Rule

`ItemDefault = ''` means no `-ForegroundColor` at all -- use terminal default.
Never pass an empty string to `-ForegroundColor`:

```powershell
if ($Theme.ItemDefault -ne '') {
    Write-Host -Object $text -ForegroundColor $Theme.ItemDefault
} else {
    Write-Host -Object $text
}
```

### Hook Function Contract

- Must return `$true` or `$false` -- return explicit bool, not pipeline output
- `Invoke-BeforeHook` calls `[Console]::Clear()` before invoking, then the menu re-renders after return
- Inherited hooks (BRANCH `before:`) run before node-level hooks, outermost first
- Any hook returning `$false` aborts silently; any hook throwing displays the message

### Token Substitution

- Tokens are `{{key}}` applied to the raw YAML string before parsing
- Works in: `label`, `description`, `call`, `import`, `params` values, `before.params` values
- Unknown tokens are left as-is -- no error thrown
- `-Context` values override vars.yaml on key conflict
- Tokens in `import:` paths resolve before the imported file is loaded

### -IndexNavigation Mode

- Items prefixed with 1-based index; digit buffer with 600ms timeout for two-digit indexes
- Single digit flushes immediately when menu has fewer than 10 items
- Up/Down/Select are no-ops; Back/Quit/Home still work; footer filters out Up/Down/Select entries
- Pass `-IndexNavigation` through every recursive `Show-MenuFrame` call

---

## Build Commands

```powershell
.\Install-Requirements.ps1              # install dev dependencies + YamlDotNet.dll
Import-Module .\Source\PSYamlTUI.psd1 -Force   # run from source
Invoke-Build -Type Local                # compile + copy lib + import
Invoke-Build -Type Full                 # git check + compile + docs + tests
```
