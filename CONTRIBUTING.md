# Contributing to PSYamlTUI

First PR? You are welcome here.

Small fixes and docs updates are great contributions.

## 1) Make your change

From repo root:

```powershell
git checkout -b my-change
```

Edit files, then run tests.

## 2) Run tests

```powershell
Invoke-Pester -Path .\Tests\PSYamlTUI.Tests.ps1 -Output Detailed
```

## 3) Commit and push

```powershell
git add .
git commit -m "short summary of change"
git push -u origin my-change
```

## 4) Open a pull request

On GitHub, open a PR from `my-change` into `main`.

Include:

- What changed
- Why it changed
- What tests you ran

## Project rules (short version)

- Keep PowerShell 5.1 compatibility.
- Use ASCII in string literals.
- Do not use `Invoke-Expression`.
- Keep path/root-jail protections intact.

## Need help?

Open an issue with your question and we can help you scope the change.
