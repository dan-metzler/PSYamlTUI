function Start-Menu {
    <#
    .SYNOPSIS
        Launches a YAML-driven terminal UI menu from a menu.yaml file.
    .DESCRIPTION
        The only exported function in PSYamlTUI. Loads and validates the menu tree from
        the specified YAML file, detects terminal capabilities, and starts the interactive
        navigation loop. Navigation is fully recursive — each submenu level is a function
        call, so going Back simply returns from that call.
    .PARAMETER Path
        Path to the root menu.yaml file. Defaults to 'menu.yaml' in the current directory.
    .PARAMETER VarsPath
        Optional path to a vars.yaml file. Must have a top-level 'vars' map. Any
        {{key}} tokens in the YAML are replaced with matching values before parsing.
        Defaults to vars.yaml in the same directory as menu.yaml if that file exists.
    .PARAMETER Context
        Optional hashtable of runtime values merged over vars.yaml. Context wins on
        any key conflict. Use for values only known at launch time: current user,
        session tokens, live environment variable values.
    .PARAMETER Theme
        Optional theme override hashtable. Any omitted keys fall back to the built-in
        default theme values.
    .PARAMETER ThemePath
        Optional path to a YAML or JSON theme file. The file may be a flat mapping of
        theme keys or contain a top-level 'theme' map.
    .EXAMPLE
        Start-Menu
        # Looks for ./menu.yaml in the current directory, auto-discovers ./vars.yaml
    .PARAMETER StatusData
        Optional hashtable of label/value pairs shown in a status bar above the footer.
        Useful for displaying session context such as connected user, environment name, or
        API state. Values are display-only and never executed or parsed.
    .PARAMETER Timer
        When set, a stopwatch runs for each action executed and the elapsed time is
        displayed in a bordered box after the action completes.
    .EXAMPLE
        Start-Menu -Path 'C:\MyApp\menu.yaml' -VarsPath 'C:\MyApp\vars.yaml'
    .EXAMPLE
        Start-Menu -VarsPath .\production.vars.yaml -Context @{ currentUser = $env:USERNAME }
    .EXAMPLE
        Start-Menu -Path .\menu.yaml -ThemePath .\theme.yaml
    #>
    [CmdletBinding(DefaultParameterSetName = 'ThemeHashtable')]
    param(
        [Parameter()]
        [string]$Path = '.\menu.yaml',

        [Parameter()]
        [string]$VarsPath,

        # Runtime key/value pairs merged over vars.yaml for {{key}} token substitution.
        # Context wins on any key conflict. Use for values only known at launch time:
        # current username, session tokens, live environment variable values.
        [Parameter()]
        [hashtable]$Context,

        # Key bindings hashtable. Keys are action names; values are either a
        # [System.ConsoleKey] enum for special keys, a single-char [string] for
        # letter keys, or an array of either to allow multiple triggers per action.
        # Actions: Up, Down, Select, Back, Quit, Home
        [Parameter()]
        [hashtable]$KeyBindings = @{
            Up     = [System.ConsoleKey]::UpArrow
            Down   = [System.ConsoleKey]::DownArrow
            Select = [System.ConsoleKey]::Enter
            Back   = @([System.ConsoleKey]::Escape, 'B')
            Quit   = 'Q'
            Home   = 'H'
        },

        # Border style for the menu frame. Single, Double, Rounded, Heavy, or ASCII.
        # Falls back to ASCII automatically on terminals that do not support Unicode.
        [Parameter()]
        [ValidateSet('Single', 'Double', 'Rounded', 'Heavy', 'ASCII')]
        [string]$BorderStyle = 'Single',

        # Color theme hashtable. Any key omitted falls back to the Default theme.
        # Valid keys: Border, Title, Breadcrumb, ItemDefault, ItemSelected,
        # ItemHotkey, ItemDescription, StatusLabel, StatusValue, FooterText.
        # All values must be ConsoleColor names (e.g. 'Cyan') or '' for terminal default.
        # Pass $null or omit entirely to use the Default theme.
        [Parameter(ParameterSetName = 'ThemeHashtable')]
        [hashtable]$Theme,

        # Path to a YAML or JSON theme file. The file may be a flat mapping of theme
        # keys or contain a top-level 'theme' mapping. Internally loaded and merged
        # over the built-in defaults.
        [Parameter(ParameterSetName = 'ThemeFile')]
        [string]$ThemePath,

        # Optional key/value pairs displayed in a status bar above the footer.
        # Evaluated once at Start-Menu call time; values are never executed or parsed.
        [Parameter()]
        [hashtable]$StatusData,

        # When set, a stopwatch runs for each action and the elapsed time is
        # displayed after the action completes.
        [switch]$Timer
    )

    # -- Validate key bindings --------------------------------------------------
    try { Assert-KeyBindings -Bindings $KeyBindings }
    catch { throw $_ }

    # -- Resolve path using PS location, not .NET working dir (they can differ) --
    $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        throw "menu.yaml not found at: $resolvedPath"
    }

    # -- Terminal detection (once per Start-Menu call) -------------------------
    # Cached in module scope so Show-MenuFrame sub-calls reuse the same profile
    $script:YamlTUI_TermProfile = Get-TerminalProfile
    $script:YamlTUI_CharSet = Get-CharacterSet -TerminalProfile $script:YamlTUI_TermProfile -Style $BorderStyle
    if (-not [string]::IsNullOrWhiteSpace($ThemePath)) {
        $resolvedThemePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ThemePath)
        $script:YamlTUI_Theme = Get-ColorTheme -ThemePath $resolvedThemePath
    }
    else {
        $script:YamlTUI_Theme = Get-ColorTheme -Theme $Theme
    }

    # -- Navigation signal flags ------------------------------------------------
    # These propagate Quit and Home events up through the recursion tree
    $script:YamlTUI_Quit = $false
    $script:YamlTUI_Home = $false

    # -- Parse and validate the menu tree --------------------------------------
    try {
        $readParams = @{ Path = $resolvedPath }
        # Resolve VarsPath: explicit parameter takes priority; otherwise auto-discover
        # vars.yaml sitting next to menu.yaml (the common case requires no parameter).
        if (-not [string]::IsNullOrWhiteSpace($VarsPath)) {
            $readParams['VarsPath'] = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($VarsPath)
        }
        else {
            $autoVars = [System.IO.Path]::Combine(
                [System.IO.Path]::GetDirectoryName($resolvedPath), 'vars.yaml'
            )
            if (Test-Path -LiteralPath $autoVars) {
                $readParams['VarsPath'] = $autoVars
            }
        }
        if ($null -ne $Context) {
            $readParams['Context'] = $Context
        }
        $menuData = Read-MenuFile @readParams
    }
    catch {
        Write-Host "Failed to load menu [$($resolvedPath)]: $_" -ForegroundColor Red
        return
    }

    # -- Hide cursor for the duration of the menu interaction ------------------
    # Saved so it can be restored exactly as it was, even on early exit or error.
    # Wrapped in try/catch because [Console]::CursorVisible throws on some
    # non-Windows pseudo-TTYs that do not support the property.
    $cursorWasVisible = $true
    try { $cursorWasVisible = [Console]::CursorVisible } catch {}
    try { [Console]::CursorVisible = $false } catch {}

    try {
        # -- Start the interactive loop -----------------------------------------
        Show-MenuFrame -MenuData $menuData `
            -RootDir ([System.IO.Path]::GetDirectoryName($resolvedPath)) `
            -TermProfile $script:YamlTUI_TermProfile `
            -Chars $script:YamlTUI_CharSet `
            -Breadcrumb @() `
            -KeyBindings $KeyBindings `
            -StatusData $StatusData `
            -Theme $script:YamlTUI_Theme `
            -Timer:$Timer `
            -IsRoot

        # Clear screen on clean exit
        [Console]::Clear()
    }
    finally {
        # Always restore cursor -- user typed input will re-enable it anyway,
        # but restoring explicitly keeps the terminal clean for any follow-up commands.
        try { [Console]::CursorVisible = $cursorWasVisible } catch {}
    }
}

