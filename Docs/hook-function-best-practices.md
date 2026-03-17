# PSYamlTUI Hook Function Best Practices

This guide shows how to write reliable before hooks so end users can gate actions and recover cleanly.

## Hook Contract

A hook function must do one of these:

- return `$true` to allow execution to continue
- return `$false` to block silently and return to menu
- throw an exception to block with an error message

Hooks run before branch render or leaf execution, depending on where `before` is defined.

## Hook Name And Registration Rules

- Hook must be a PowerShell function name (not a script path).
- Hook name cannot contain path separators or file extensions.
- Hook function must be loaded in the current session before Start-Menu.
- Hook is validated via Get-Command using CommandType Function.

## YAML Shapes

Shorthand (no params):

```yaml
before: "Assert-ApiSession"
```

Single hook with params:

```yaml
before:
  hook: "Assert-ApiSession"
  params:
    tenant: "{{environment}}"
```

Multiple hooks in order:

```yaml
before:
  - hook: "Assert-ApiSession"
    params:
      tenant: "{{environment}}"
  - hook: "Assert-NetworkAccess"
    params:
      target: "prod"
```

## Inheritance And Order

- Branch-level hooks are inherited by all descendants.
- Inherited hooks run first (outermost to innermost).
- Node-level hooks run after inherited hooks.
- First `$false` or throw stops remaining hooks.

## Design Guidelines

- Keep hooks focused on gating only.
- Use typed parameters with validation attributes.
- Return explicit booleans, do not rely on pipeline output.
- Keep side effects minimal and intentional.
- Make hooks idempotent where possible.
- Prefer short, actionable error messages when throwing.
- Avoid external dependencies unless required for gating.

## Parameter Best Practices

- Define all expected inputs in `param()`.
- Mark truly required values as mandatory.
- Use ValidateSet for fixed values.
- Use ValidateRange and ValidatePattern where appropriate.
- Keep params scalar (string, bool, number) to match menu schema.

Example:

```powershell
function Assert-ExampleRole {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Reader','Operator','Admin')]
        [string]$RequiredRole,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$CurrentUser
    )

    if ([string]::IsNullOrWhiteSpace($CurrentUser)) {
        throw 'Hook failed: CurrentUser is empty.'
    }

    return $true
}
```

## Interactive Recovery Pattern

For auth hooks, it is valid to prompt and recover.

Pattern:

1. Check current state.
2. If valid, return `$true`.
3. If invalid, prompt for credential/input.
4. Retry validation.
5. Return `$true` on success, `$false` on cancel/failure.

Example:

```powershell
function Assert-ExampleAuth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool]$IsAuthenticated,

        [Parameter(Mandatory)]
        [string]$UserName
    )

    if ($IsAuthenticated) { return $true }

    $credential = Get-Credential -Message 'Authenticate to continue.' -UserName $UserName
    if ($null -eq $credential) { return $false }

    if ([string]::IsNullOrWhiteSpace($credential.GetNetworkCredential().Password)) {
        return $false
    }

    return $true
}
```

## When To Return False vs Throw

Return `$false` when:

- user cancelled input
- auth failed but is not exceptional
- precondition not met and quiet block is preferred

Throw when:

- invalid configuration
- corrupt state
- dependency failure users should see immediately

## Status Bar Updates From Hooks

Hooks may update status data used by the menu. For example:

```powershell
$script:YamlTUI_StatusData['Connected As'] = $UserName
$script:YamlTUI_StatusData['Tenant'] = $Tenant
```

Use this only for display updates related to gate results.

## Anti-Patterns To Avoid

- Running main business logic in hooks.
- Returning non-bool values as gate results.
- Swallowing errors silently in catch blocks.
- Using hooks for post-execution behavior.
- Relying on unscoped functions not loaded before Start-Menu.

## Pre-Ship Hook Checklist

- Function name matches YAML `hook` exactly.
- Function is loaded before Start-Menu.
- All mandatory params provided by `before.params`.
- Hook returns explicit `$true` or `$false`.
- Exceptional failures throw clear errors.
- Interactive prompt path is tested for cancel and success.
- Hook order and inheritance behavior are verified in nested menus.
