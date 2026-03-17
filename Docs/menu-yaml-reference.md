# PSYamlTUI `menu.yaml` Feature Reference

See also:

- `Docs/root-jail-security.md`
- `Docs/hook-function-best-practices.md`

## File Structure

```yaml
# Root file -- must have a top-level `menu:` wrapper
menu:
  title: "My Menu"
  items:
    - ...

# Submenu files (referenced via import:) -- top-level `items:` key only, no wrapper
items:
  - ...
```

---

## Node Types

| What you put in the node | What it does |
|---|---|
| `exit: true` | Clean quit -- exits the menu system |
| `children:` or `import:` | Branch -- opens a submenu |
| `call: "./script.ps1"` | Script -- executes a `.ps1` file |
| `call: "My-Function"` | Function -- calls a loaded PS function |

---

## All Node Properties

| Key | Type | Notes |
|---|---|---|
| `label` | string | **Required.** Display text |
| `exit` | bool | Marks as EXIT node |
| `children` | list | Inline submenu items |
| `import` | string | Path to an external `.yaml` submenu file (relative only) |
| `call` | string | Script path or PS function name |
| `params` | map | Key/value pairs splatted to the call. Strings, bools, numbers only |
| `confirm` | bool | Prompts Y/N before executing |
| `description` | string | Subtitle shown under the item when selected |
| `hotkey` | string | Single character shortcut (case-insensitive) |
| `before` | string or map or list | Pre-execution hook(s) -- see hooks section |

---

## Token Substitution

Tokens in `{{key}}` form are replaced before parsing. Works in: `label`, `description`, `call`, `import`, `params` values, `before` params values.

**Source 1 -- `vars.yaml`** (auto-discovered next to `menu.yaml`, or via `-VarsPath`):
```yaml
vars:
  scriptsPath: "./scripts"
  environment: "prod"
  apiBase:     "https://api.internal.com"
```

**Source 2 -- `-Context` hashtable** (runtime values, wins over `vars.yaml` on conflict):
```powershell
Start-Menu -Context @{ currentUser = $env:USERNAME }
```

Usage in YAML:
```yaml
- label:  "Deploy to {{environment}}"
  call:   '{{scriptsPath}}/Deploy.ps1'   # single quotes -- safe with backslash paths
  params:
    env:  "{{environment}}"
    user: "{{currentUser}}"
```

Unknown tokens are left as-is -- no error thrown.

---

## Importing Submenu Files

```yaml
- label:  "Accounts"
  import: "./menus/accounts.yaml"        # always relative to root menu.yaml
```

- The imported file uses `items:` at root (no `menu:` wrapper)
- Import chains are supported (imported files can themselves import further)
- Token substitution applies to `import:` paths before the file is loaded

---

## Inline Submenus

```yaml
- label: "Tools"
  children:
    - label: "Run Diagnostics"
      call:  "./scripts/Run-Diag.ps1"
    - label: "Back"
      exit:  true
```

A node cannot have both `children:` and `import:`.

---

## Before Hooks

Gates that run before a leaf executes or a branch renders. Must return `$true` to proceed, `$false` to abort silently, or throw to abort with a message.

```yaml
# Shorthand -- single hook, no params
before: "Assert-ApiSession"

# Single hook with params
before:
  hook:   "Assert-ApiSession"
  params:
    role:   "admin"
    tenant: "{{environment}}"

# Multiple hooks -- run in order, first failure stops the chain
before:
  - hook: "Assert-ApiSession"
    params:
      role: "admin"
  - hook: "Assert-NetworkAccess"
    params:
      target: "prod-cluster"
```

- Defined on a **branch node** -- inherited by every descendant node
- Defined on a **leaf node** -- runs before that node's `call`
- Inherited hooks run first (outermost to innermost), then node-level hooks
- Hook names must be plain PS function names -- no path chars, no extension

---

## Confirm Prompt

```yaml
- label:   "Delete All Logs"
  confirm: true
  call:    "./scripts/Remove-Logs.ps1"
```

Presents a Y/N prompt before executing. Hooks run before the confirm prompt.

---

## Security Rules (enforced at parse time)

- `import:` paths must be relative -- absolute paths are rejected
- `call:` values containing `|`, `;`, `&`, `>` are rejected
- Hook names must not contain path separators or file extensions
- `params` values must be strings, bools, or numbers -- no nested objects
- `hotkey` must be a single character

---

## Full Example

```yaml
menu:
  title: "{{appName}} Admin"
  items:

    - label:       "Cloud Accounts"
      description: "Manage cloud account provisioning"
      before:
        hook:   "Assert-ApiSession"
        params:
          tenant: "{{environment}}"
      children:

        - label:   "Create Account"
          hotkey:  "C"
          call:    '{{scriptsPath}}/New-Account.ps1'
          params:
            type:  "cloud2"
            env:   "{{environment}}"

        - label:   "Delete Account"
          hotkey:  "D"
          confirm: true
          before:
            hook:   "Assert-ApiSession"
            params:
              role: "admin"
          call:    '{{scriptsPath}}/Remove-Account.ps1'

    - label:  "Reports"
      import: "./menus/reports.yaml"

    - label: "Exit"
      exit:  true
```
