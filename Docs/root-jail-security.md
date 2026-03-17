# PSYamlTUI Root-Jail Security Guide

This guide explains how script path security works in PSYamlTUI and how to structure menus so actions run successfully.

## What Root-Jail Means

When a menu node uses a script call (for example `call: "./scripts/Do-Thing.ps1"`), PSYamlTUI resolves that path and enforces a jail boundary.

The boundary is the directory that contains the root menu file passed to Start-Menu.

If the resolved script path is outside that boundary, execution is blocked with:

`Security: script path '...' resolves outside the root directory.`

## Why It Exists

Root-jail prevents menu YAML from escaping into arbitrary filesystem locations and executing unexpected scripts.

This helps protect users from:

- path traversal (`..\\..\\` style escapes)
- accidental absolute path usage
- tampered menu files that attempt unsafe execution

## How Paths Are Resolved

1. Start from the root menu directory.
2. Combine root directory + `call` value.
3. Canonicalize to a full path.
4. Verify the full path still starts with the root directory.
5. If yes, run script. If no, block.

## Examples

Assume root menu path is:

`C:\Apps\MyMenu\menu.yaml`

Root directory is:

`C:\Apps\MyMenu`

Allowed:

```yaml
call: "./scripts/Get-Report.ps1"
call: "./ops/maintenance/Clear-Cache.ps1"
```

Blocked:

```yaml
call: "../scripts/Get-Report.ps1"
call: "../../Windows/System32/notepad.exe"
call: "C:\OtherFolder\Do-Thing.ps1"
```

## Best Practices For Menu Authors

- Keep executable scripts inside the same root menu tree.
- Use a local scripts folder such as `./scripts` from the root menu directory.
- If you use token substitution for script paths, keep the token value jail-safe.
- Prefer single quotes around tokenized script paths in YAML to avoid escape issues:

```yaml
call: '{{scriptsPath}}/Get-Report.ps1'
```

- Keep `import` paths relative and inside the same root tree.

## Common Troubleshooting

### Error: resolves outside root directory

Cause:
- `call` path points above the root menu directory.

Fix:
- Move script under the root menu directory.
- Update path to `./scripts/...` form.

### Script not found

Cause:
- Path is jail-safe but file does not exist.

Fix:
- Verify filename and extension.
- Confirm file is present in the resolved location.

### Works in dev, fails for users

Cause:
- Local machine had scripts in a different folder layout.

Fix:
- Package menu files and called scripts together under one root tree.
- Test from a clean directory using only packaged files.

## Packaging Checklist

- Root `menu.yaml` included.
- All imported submenu YAML files included.
- All script call targets included under the same root menu directory.
- Any vars file paths resolve within the package.
- Any theme files are present and referenced correctly.
