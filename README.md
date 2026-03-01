# PSNewModule — PowerShell module scaffold

A forkable starter repository for quickly scaffolding a new PowerShell module. Use this repo as a template when you have a new module idea — it wires up common build, test and packaging tasks using Invoke-Build and ModuleBuilder.

Why use this repo
- Small, focused scaffold for new PowerShell modules.
- Includes build automation with [Invoke-Build](https://github.com/nightroman/Invoke-Build).
- Includes module packaging helper via [ModuleBuilder](https://github.com/PoshCode/ModuleBuilder).
- Simple test integration and convenience scripts to get started fast.

Repository layout
- `Install-Requirements.ps1` — optional helper to install dependencies.
- `.build.ps1` — Invoke-Build task definitions.
- `Build/BuildFunctions.ps1` — helper functions used by the build (e.g. `Test-GitStatus`).
- `Source/` — module source and builder script (`ModuleBuilder.ps1`, `NewModule.psd1`, `NewModule.psm1`).
- `Output/` — build output (package artifacts).
- `Tests/` — Pester tests.

Prerequisites
- PowerShell 7+ (or PowerShell 5.1 where compatible).
- Git on PATH.
- Optional: run `Install-Requirements.ps1` to install `Invoke-Build` and `Pester` if not present.

Quick start
1. Fork this repository and clone your fork locally.

2. From the repo root, (optionally) bootstrap requirements:

```powershell
.\Install-Requirements.ps1
```

3. Run the build tasks.

Run all default tasks (CheckGit → folderCleanup → BuildModule → Test):

```powershell
Invoke-Build
```

Or run individual tasks:

Check git status (verifies branch and uncommitted changes):

```powershell
Invoke-Build CheckGit -Verbose
```

Build the module (uses `Source\ModuleBuilder.ps1`):

```powershell
Invoke-Build BuildModule
```

Run tests:

```powershell
Invoke-Build Test
```

Notes on `-Verbose`
This project uses `[CmdletBinding()]` in helper functions so passing `-Verbose` to `Invoke-Build` will surface diagnostic `Write-Verbose` output from functions like `Test-GitStatus`.

How to scaffold a new module from this template
1. Update `Source\NewModule.psd1` and `Source\NewModule.psm1` with your module metadata and code.
2. Update or extend `Build/BuildFunctions.ps1` for any custom build checks or packaging steps.
3. Adjust `Tests/` to include Pester tests for your module functions.
4. Use `Invoke-Build` tasks to run the same CI-style steps locally and in CI.

Customizing the build
- Add or modify tasks in `.build.ps1` for additional steps (linting, changelog generation, publishing).
- The build currently dot-sources `Build/BuildFunctions.ps1` so any new functions there are immediately available to tasks.

Contributing
- This repository is intended as a personal/team template. Fork it, adapt it, and keep a clean history for your projects.