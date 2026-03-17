# PSYamlTUI Examples

This folder contains simple, intermediate, and advanced launch examples.

## Run The Launchers

- .\Docs\Examples\MenuLaunchers\Simple-Example.ps1
- .\Docs\Examples\MenuLaunchers\Intermediate-Example.ps1
- .\Docs\Examples\MenuLaunchers\Advanced-Example.ps1

## Visual Theme Profiles

Each launcher now uses a different theme profile for a clear visual identity:

- Simple: clean blue/cyan style for quick read-only actions
- Intermediate: amber/green operations style with stronger status contrast
- Advanced: deeper green/yellow style for power-user flows and hook demos

Theme files:

- Docs/Examples/Fixtures/themes/simple.theme.json
- Docs/Examples/Fixtures/themes/intermediate.theme.json
- Docs/Examples/Fixtures/themes/advanced.theme.json

## Advanced Hook Behavior Demo

Note on script paths in advanced fixtures:
- The module enforces a root-jail for script execution.
- Advanced menu script calls use ./scripts under Fixtures/menus.
- This keeps all advanced call targets inside the root menu directory.

The advanced menu includes an intentional blocked action to demonstrate before hook behavior.

It also includes an auth recovery action to demonstrate hook-driven remediation that can
return true and allow execution to continue.

Auth recovery path in menu:
- Platform Operations
- Auth Recovery Demo - Hook resolves to true

What to expect for auth recovery:
- The before hook Test-ExampleAuthRecovery starts with IsAuthenticated set to false.
- The hook prompts for credentials.
- If a non-empty password is entered, the hook returns true.
- The target action executes after the hook returns true.
- If credential input is cancelled or empty, the hook returns false and action is blocked.

Path in menu:
- Platform Operations
- Blocked Demo - Hook returns false

What to expect:
- The before hook Test-ExampleBlockedAction returns false.
- The target call does not run.
- No exception is shown.
- Control returns to the menu normally.

Related files:
- Docs/Examples/Fixtures/menus/advanced.operations.menu.yaml
- Docs/Examples/Scripts/Register-ExampleHooks.ps1
