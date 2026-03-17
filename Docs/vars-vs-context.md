# PSYamlTUI vars.yaml vs -Context

This guide explains the difference between `vars.yaml` and `-Context`, when to use each one, and how they work together.

## Short Version

- `vars.yaml` or `-VarsPath` = static values stored in a file
- `-Context` = dynamic values supplied at runtime

If the same key exists in both places, `-Context` wins.

## What vars.yaml Is For

Use `vars.yaml` for values that are stable and belong to the menu or environment itself.

Good examples:

- application name
- environment name
- region
- script base path
- API base URL
- common labels or endpoints

Example:

```yaml
vars:
  appName: "MyApp"
  environment: "production"
  region: "us-east-1"
  scriptsPath: "./scripts"
```

## What -Context Is For

Use `-Context` for values that are only known when the menu is launched.

Good examples:

- current username
- current tenant
- session ID
- selected profile
- machine-specific values
- values returned by a login step or other live lookup

Example:

```powershell
Start-Menu -Context @{
    currentUser = $env:USERNAME
    sessionId   = 'abc123'
}
```

## Merge Behavior

PSYamlTUI resolves token values in this order:

1. Load vars from `vars.yaml` or `-VarsPath`
2. Merge `-Context` over the top
3. Replace `{{key}}` tokens before YAML is parsed

If both define the same key, `-Context` overrides the file value.

Example:

```yaml
vars:
  environment: "dev"
  region: "us-east-1"
```

```powershell
Start-Menu -VarsPath .\vars.yaml -Context @{ environment = 'production' }
```

Result:

- `{{environment}}` becomes `production`
- `{{region}}` stays `us-east-1`

## Recommended Pattern

Use the file for defaults and environment configuration.
Use context for live values.

Example:

```yaml
vars:
  appName: "PSYamlTUI"
  environment: "production"
  region: "us-east-1"
  scriptsPath: "./scripts"
```

```powershell
Start-Menu -VarsPath .\production.vars.yaml -Context @{
    currentUser = $env:USERNAME
    tenant      = 'finance'
}
```

## When To Use Only vars.yaml

Use only `vars.yaml` when:

- values do not change per user or per session
- the menu is environment-driven, not session-driven
- you want a simple deployment with minimal launch logic

## When To Use Both

Use both when:

- the menu has environment defaults
- some values depend on who launched the menu
- some values are only known after login or runtime checks

This is the most common real-world pattern.

## Common Mistakes

### Putting live values in vars.yaml

Avoid storing values like current user, tokens, or session identifiers in the vars file.

### Expecting vars.yaml to override context

It does not. Context always wins on duplicate keys.

### Using backslash-heavy runtime values inside double-quoted YAML values

If runtime values may contain backslashes, prefer single-quoted YAML strings when practical.

Example:

```yaml
call: '{{scriptsPath}}/Do-Thing.ps1'
```

## Practical Example

Menu YAML:

```yaml
menu:
  title: "{{appName}} - {{environment}}"
  items:
    - label: "Deploy as {{currentUser}}"
      call: '{{scriptsPath}}/Deploy.ps1'
      params:
        env: "{{environment}}"
        region: "{{region}}"
        user: "{{currentUser}}"
```

Vars file:

```yaml
vars:
  appName: "MyApp"
  environment: "production"
  region: "us-east-1"
  scriptsPath: "./scripts"
```

Launcher:

```powershell
Start-Menu -VarsPath .\vars.yaml -Context @{
    currentUser = $env:USERNAME
}
```

## Rule Of Thumb

- If the value should live in source control, put it in `vars.yaml`.
- If the value is discovered at launch, put it in `-Context`.
