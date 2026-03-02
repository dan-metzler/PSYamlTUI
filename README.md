# PSNewModule

Minimal PowerShell module template with build, test, and docs automation.

## What this repo includes

- `Invoke-Build` pipeline (`.build.ps1`)
- Module packaging with `ModuleBuilder` (`Source/ModuleBuilder.ps1`)
- Pester tests (`Tests/`)
- Markdown help generation with `platyPS` (`Docs/`)

## Prerequisites

- PowerShell 5.1+ (PowerShell 7 recommended)
- Git
- PowerShellGet access to install modules

## Install dependencies

From repo root:

```powershell
.\Install-Requirements.ps1
```

This installs required modules using min/max version ranges:

- `ModuleBuilder` (3.1.8 - 4.x)
- `Pester` (3.4.0 - 5.x)
- `InvokeBuild` (5.14.23 - 6.x)
- `platyPS` (0.14.2 - 1.x)

## Build pipeline

Run full pipeline:

```powershell
Invoke-Build
```

Default task order:

1. `CheckGitStatus` (expects `main` branch)
2. `BuildModule`
3. `ModuleImport`
4. `GenerateMarkdownDocs`
5. `RunTests`

## Run individual tasks

```powershell
Invoke-Build CheckGitStatus
Invoke-Build BuildModule
Invoke-Build ModuleImport
Invoke-Build GenerateMarkdownDocs
Invoke-Build RunTests
```

## Folder layout

- `Source/` - module source (`.psm1`, `.psd1`, `Public/`, `Private/`)
- `Output/` - built module artifact
- `Tests/` - Pester tests
- `Docs/` - generated markdown help
- `Build/` - shared build helper functions

## Common workflow

1. Add/modify functions in `Source/Public` or `Source/Private`
2. Add/update tests in `Tests`
3. Run `Invoke-Build`
4. Import built module from `Output/NewModule`

## Fork setup checklist

When creating a new module from this template, update these first:

1. **Module manifest**: `Source/NewModule.psd1`
	- `RootModule`, `ModuleVersion`, `GUID`
	- `Author`, `CompanyName`, `Description`
	- `Tags`, `ProjectUri`, `LicenseUri`
	- `FunctionsToExport` / `CmdletsToExport` / `AliasesToExport`
2. **Module file name(s)**
	- Rename `Source/NewModule.psm1` and `Source/NewModule.psd1` to your module name
	- Keep manifest `RootModule` aligned with the `.psm1` file name
3. **Tests**
	- Replace sample tests in `Tests/`
	- Update any hardcoded module import path/name references
4. **Build defaults**
	- If your default branch is not `main`, update `CheckGitStatus` in `.build.ps1`
5. **Dependencies**
	- Adjust module version policy in `Install-Requirements.ps1` (minimum/maximum ranges)
6. **Documentation**
	- Replace sample function help with your own comment-based help in `Source/Public/*.ps1`
	- Regenerate markdown docs via `Invoke-Build GenerateMarkdownDocs`
7. **README metadata**
	- Update project name, usage examples, and links in this file

## Notes

- `Source/ModuleBuilder.ps1` builds from source manifest and writes to `Output/<ModuleName>`.
- Markdown help generation depends on `ModuleImport` build task so the module name is available during docs generation.