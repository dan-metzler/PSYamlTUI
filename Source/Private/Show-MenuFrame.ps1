function Read-ConsoleKey {
    <#
    .SYNOPSIS
        Thin wrapper around [Console]::ReadKey so tests can mock it.
        When -NonBlocking is set, returns $null immediately if no key is buffered.
    #>
    [CmdletBinding()]
    [OutputType([System.ConsoleKeyInfo])]
    param(
        [switch]$NonBlocking
    )
    if ($NonBlocking) {
        if (-not [Console]::KeyAvailable) { return $null }
    }
    return [Console]::ReadKey($true)
}

function Clear-ConsoleSafe {
    [CmdletBinding()]
    param(
        [PSCustomObject]$TermProfile,
        # When set, erase to end of screen after cursor-home. Required before script
        # output or prompts -- the fixed-frame overwrite assumption does not hold there.
        [switch]$Full
    )

    if ($null -ne $TermProfile -and $TermProfile.UseAnsi) {
        if ($Full) {
            # Scrollback clear + cursor-home + erase to end of screen.
            # ESC[3J clears the scrollback buffer so previous script output does not
            # remain visible above the menu frame. Silently ignored by terminals that
            # do not support it, so no regression on older hosts.
            [Console]::Write(([char]27) + '[3J' + ([char]27) + '[H' + ([char]27) + '[J')
        }
        else {
            # Scrollback clear + cursor-home. Build-AnsiFrame + ESC[J] covers the
            # current viewport; ESC[3J prevents prior output showing above the frame.
            [Console]::Write(([char]27) + '[3J' + ([char]27) + '[H')
        }
        return
    }

    try {
        [Console]::Clear()
    }
    catch {
        # Non-interactive host (for example CI) can throw invalid handle.
    }
}

function Show-MenuFrame {
    <#
    .SYNOPSIS
        Displays a menu level and handles interactive navigation. Recursion IS the stack.
    .DESCRIPTION
        Renders the full menu frame, reads keystrokes, and dispatches actions.
        Navigating into a BRANCH calls Show-MenuFrame recursively. Going Back simply
        returns from the current call — no explicit stack management needed.

        Module-scoped flags ($script:YamlTUI_Quit, $script:YamlTUI_Home) propagate
        exit signals upward through the recursion automatically.
    .PARAMETER MenuData
        PSCustomObject with Title (string) and Items (array of validated nodes).
    .PARAMETER RootDir
        Root directory of the original menu.yaml. Passed to Invoke-MenuAction.
    .PARAMETER TermProfile
        Terminal capability profile from Get-TerminalProfile.
    .PARAMETER Chars
        Character set hashtable from Get-CharacterSet.
    .PARAMETER Breadcrumb
        Array of parent menu titles, built up as the user navigates deeper.
    .PARAMETER IsRoot
        Switch — set only on the first call from Start-Menu. The root frame does not
        exit on Home; it clears the Home signal and re-renders instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$MenuData,

        [Parameter(Mandatory)]
        [string]$RootDir,

        [Parameter(Mandatory)]
        [PSCustomObject]$TermProfile,

        [Parameter(Mandatory)]
        [hashtable]$Chars,

        [string[]]$Breadcrumb = @(),

        [switch]$IsRoot,

        [Parameter(Mandatory)]
        [hashtable]$KeyBindings,

        # Optional status bar data passed through from Start-Menu.
        [Parameter()]
        [hashtable]$StatusData,

        # When set, a stopwatch runs for each action and the elapsed time is
        # displayed after the action completes.
        [switch]$Timer,

        # Before hooks inherited from ancestor BRANCH nodes. Any hooks defined on
        # a BRANCH are accumulated and passed down so they gate both submenu entry
        # and leaf execution at every nested level.
        [Parameter()]
        [array]$InheritedHooks = @(),

        [Parameter(Mandatory)]
        [hashtable]$Theme,

        # When set, items are prefixed with 1-based numbers and input is handled
        # via digit entry instead of arrow keys. Back/Quit/Home remain active.
        # Passed through every recursive Show-MenuFrame call so submenus inherit it.
        [switch]$IndexNavigation
    )

    # @() forces the value to always be an array -- PS pipeline-unwraps a single-item
    # return value from Resolve-MenuItems to a scalar PSCustomObject, which has no .Count
    # property. A null .Count makes the index-mode validity check (0 -lt $null) fail,
    # silently blocking selection in any menu or submenu with exactly one item.
    $items = @($MenuData.Items)
    $title = $MenuData.Title
    $idx = 0
    $running = $true
    $partialNavPrev = -1
    $partialNavNew  = -1
    $innerWidth = [Math]::Max(38, [Math]::Min($TermProfile.Width - 4, 96))

    while ($running) {
        # Home signal: at root we stay and re-render; elsewhere we bubble up
        if ($IsRoot -and $script:YamlTUI_Home) { $script:YamlTUI_Home = $false }

        if ($partialNavPrev -ge 0) {
            Write-AnsiNavUpdate -Items $items -PrevIdx $partialNavPrev -NewIdx $partialNavNew `
                -Breadcrumb $Breadcrumb -InnerWidth $innerWidth -Chars $Chars -Theme $Theme
            $partialNavPrev = -1
            $partialNavNew  = -1
        }
        else {
            Write-MenuFrame -Title $title -Items $items -SelectedIndex $idx `
                -Breadcrumb $Breadcrumb -TermProfile $TermProfile -Chars $Chars -KeyBindings $KeyBindings `
                -IndexNavigation:$IndexNavigation -StatusData $StatusData -Theme $Theme
        }

        if ($IndexNavigation) {
            # -- Index mode: digit buffer with timeout, Back/Quit/Home still active -
            $bufferTimeout = 600  # ms -- not a parameter in v1
            $digitBuffer = ''
            $lastKeyTime = [DateTime]::Now
            $action = $null
            while ($null -eq $action) {
                if ($digitBuffer -ne '') {
                    $elapsed = ([DateTime]::Now - $lastKeyTime).TotalMilliseconds
                    if ($elapsed -ge $bufferTimeout) {
                        $resolvedIdx = [int]$digitBuffer - 1
                        $digitBuffer = ''
                        if ($resolvedIdx -ge 0 -and $resolvedIdx -lt $items.Count) {
                            $idx = $resolvedIdx
                            $action = 'Select'
                        }
                        else {
                            $action = '_Noop'
                        }
                        break
                    }
                }

                $key = Read-ConsoleKey -NonBlocking
                if ($null -eq $key) {
                    Start-Sleep -Milliseconds 50
                    continue
                }

                if ($key.KeyChar -match '^\d$') {
                    $digitBuffer += $key.KeyChar
                    $lastKeyTime = [DateTime]::Now
                    $maxIndex = $items.Count
                    # Flush immediately when the buffer cannot grow to a valid two-digit index.
                    # Single digit is unambiguous when fewer than 10 items, or when the first
                    # digit already exceeds the tens digit of the item count.
                    if ($maxIndex -lt 10 -or [int]$digitBuffer -gt [Math]::Floor($maxIndex / 10)) {
                        $resolvedIdx = [int]$digitBuffer - 1
                        $digitBuffer = ''
                        if ($resolvedIdx -ge 0 -and $resolvedIdx -lt $items.Count) {
                            $idx = $resolvedIdx
                            $action = 'Select'
                        }
                        else {
                            $action = '_Noop'
                        }
                    }
                    continue
                }

                # Non-digit key: flush buffer and resolve named action
                $digitBuffer = ''
                $resolved = Resolve-KeyAction -Key $key -Bindings $KeyBindings
                $action = if ($null -ne $resolved) { $resolved } else { '_Noop' }
            }
        }
        else {
            # -- Keybinding mode (default): single key resolves immediately --------
            $key = Read-ConsoleKey
            $action = Resolve-KeyAction -Key $key -Bindings $KeyBindings
        }

        switch ($action) {
            'Up' {
                # No-op in index mode -- navigation is by number, not arrow key
                if (-not $IndexNavigation) {
                    $prevIdx = $idx
                    if ($idx -gt 0) { $idx-- } else { $idx = $items.Count - 1 }
                    if ($TermProfile.UseAnsi -and
                        $null -eq $items[$prevIdx].Description -and
                        $null -eq $items[$idx].Description) {
                        $partialNavPrev = $prevIdx
                        $partialNavNew  = $idx
                    }
                }
            }
            'Down' {
                # No-op in index mode -- navigation is by number, not arrow key
                if (-not $IndexNavigation) {
                    $prevIdx = $idx
                    if ($idx -lt ($items.Count - 1)) { $idx++ } else { $idx = 0 }
                    if ($TermProfile.UseAnsi -and
                        $null -eq $items[$prevIdx].Description -and
                        $null -eq $items[$idx].Description) {
                        $partialNavPrev = $prevIdx
                        $partialNavNew  = $idx
                    }
                }
            }
            'Select' {
                $sel = $items[$idx]

                if ($sel.NodeType -eq 'EXIT') {
                    $script:YamlTUI_Quit = $true
                    $running = $false

                }
                elseif ($sel.NodeType -eq 'BRANCH') {
                    # Accumulate hooks: inherited from ancestor frames + this branch's own.
                    # The combined list is passed to the recursive frame so all descendants
                    # inherit every ancestor hook as well as this branch's hooks.
                    $hooksList = [System.Collections.Generic.List[object]]::new()
                    foreach ($h in $InheritedHooks) { $hooksList.Add($h) }
                    if ($null -ne $sel.Before -and $sel.Before.Count -gt 0) {
                        foreach ($h in $sel.Before) { $hooksList.Add($h) }
                    }

                    $branchProceeds = $true
                    if ($hooksList.Count -gt 0) {
                        try {
                            $hookResult = Invoke-BeforeHook -Hooks $hooksList.ToArray()
                            if ($hookResult -eq $false) { $branchProceeds = $false }
                        }
                        catch {
                            Clear-ConsoleSafe -TermProfile $TermProfile -Full
                            Write-Host ''
                            Write-Host "  Hook error: $_" -ForegroundColor Red
                            Write-Host ''
                            Write-Host '  Press any key to return to menu...' -ForegroundColor $Theme.FooterText
                            $null = Read-ConsoleKey
                            $branchProceeds = $false
                        }
                    }

                    if ($branchProceeds) {
                        $sub = [PSCustomObject]@{ Title = $sel.Label; Items = $sel.Children }
                        $newCrumb = $Breadcrumb + @($title)
                        # Recursive call -- returning from it means the user pressed Back.
                        # Pass accumulated hooks so all descendants inherit them.
                        Show-MenuFrame -MenuData $sub -RootDir $RootDir -TermProfile $TermProfile `
                            -Chars $Chars -Breadcrumb $newCrumb -KeyBindings $KeyBindings `
                            -StatusData $StatusData -Theme $Theme -Timer:$Timer `
                            -IndexNavigation:$IndexNavigation `
                            -InheritedHooks $hooksList.ToArray()
                    }

                }
                else {
                    # SCRIPT or FUNCTION node
                    $proceed = $true

                    # Collect and run before hooks before the confirm prompt and execution.
                    # Inherited hooks (from ancestor BRANCHes) run first, then node-level hooks.
                    $hooksList = [System.Collections.Generic.List[object]]::new()
                    foreach ($h in $InheritedHooks) { $hooksList.Add($h) }
                    if ($null -ne $sel.Before -and $sel.Before.Count -gt 0) {
                        foreach ($h in $sel.Before) { $hooksList.Add($h) }
                    }

                    if ($hooksList.Count -gt 0) {
                        try {
                            $hookResult = Invoke-BeforeHook -Hooks $hooksList.ToArray()
                            if ($hookResult -eq $false) { $proceed = $false }
                        }
                        catch {
                            Clear-ConsoleSafe -TermProfile $TermProfile -Full
                            Write-Host ''
                            Write-Host "  Hook error: $_" -ForegroundColor Red
                            Write-Host ''
                            Write-Host '  Press any key to return to menu...' -ForegroundColor $Theme.FooterText
                            $null = Read-ConsoleKey
                            $proceed = $false
                        }
                    }

                    if ($proceed -and $sel.Confirm) {
                        Clear-ConsoleSafe -TermProfile $TermProfile -Full
                        Write-Host ''
                        Write-Host "  Confirm: $($sel.Label)" -ForegroundColor $Theme.ItemSelected
                        if ($null -ne $sel.Description) {
                            Write-Host "  $($sel.Description)" -ForegroundColor $Theme.ItemDescription
                        }
                        Write-Host ''
                        Write-Host '  Are you sure? [Y/N]: ' -NoNewline -ForegroundColor $Theme.ItemSelected
                        $ck = Read-ConsoleKey
                        Write-Host $ck.KeyChar
                        $proceed = ($ck.KeyChar -ieq 'y')
                    }

                    if ($proceed) {
                        Clear-ConsoleSafe -TermProfile $TermProfile -Full
                        if (-not [string]::IsNullOrEmpty($sel.Details)) {
                            Write-BorderedText -Title 'Running...' -Text "$($sel.Label)" -Details $sel.Details -TextColor $Theme.Title -BorderColor $Theme.Border -Chars $Chars
                        }
                        else {
                            Write-BorderedText -Title 'Running...' -Text "$($sel.Label)" -TextColor $Theme.Title -BorderColor $Theme.Border -Chars $Chars
                        }
                        Write-Host ''

                        if ($Timer) {
                            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                        }

                        try { [Console]::CursorVisible = $true } catch {}
                        try {
                            Invoke-MenuAction -Node $sel -RootDir $RootDir
                        }
                        catch {
                            Write-Host "`nError: $_" -ForegroundColor Red
                        }
                        try { [Console]::CursorVisible = $false } catch {}

                        if ($Timer) {
                            $stopwatch.Stop()
                            $e = $stopwatch.Elapsed
                            $esc = [char]27
                            $r = "${esc}[0m"
                            $brightGreen = "${esc}[92m"
                            $brightYellow = "${esc}[93m"
                            $brightBlue = "${esc}[94m"
                            $brightMagenta = "${esc}[95m"
                            $darkGray = "${esc}[90m"
                            $white = "${esc}[37m"

                            $timerString = "${darkGray}$($Chars.BottomLeft)$($Chars['Arrow'])${r} ${white}$($e.ToString('hh'))${r}${brightBlue}h${r} ${white}$($e.ToString('mm'))${r}${brightMagenta}m${r} ${white}$($e.ToString('ss'))${r}${brightGreen}s${r} ${white}$($e.ToString('fff'))${r}${brightYellow}ms${r}"
                            Write-BorderedText -Title "Runtime" -Text $timerString -TextColor $Theme.Title -BorderColor 'DarkGray' -Chars $Chars
                        }

                        Write-Host ''
                        Write-Host '  Press any key to return to menu...' -ForegroundColor $Theme.FooterText
                        try { while ([Console]::KeyAvailable) { $null = [Console]::ReadKey($true) } } catch {}
                        $null = Read-ConsoleKey
                    }
                }
            }
            'Back' {
                # Back is silently ignored at root
                if (-not $IsRoot) { $running = $false }
            }
            'Quit' {
                $script:YamlTUI_Quit = $true
                $running = $false
            }
            'Home' {
                if ($IsRoot) {
                    # Already at root — Home is a no-op, just re-render from top
                    $idx = 0
                }
                else {
                    $script:YamlTUI_Home = $true
                    $running = $false
                }
            }
            default {
                # Check item-defined hotkeys (case-insensitive).
                # Resolve-KeyAction returns $null for unrecognised keys, which
                # falls through to here — so this also runs for unbound keys.
                $ch = [string]$key.KeyChar
                if ($ch -ne '') {
                    for ($i = 0; $i -lt $items.Count; $i++) {
                        if ($null -ne $items[$i].Hotkey -and $items[$i].Hotkey -ieq $ch) {
                            $idx = $i
                            break
                        }
                    }
                }
            }
        }

        # Propagate quit/home signals upward by stopping this level
        if (-not $IsRoot -and ($script:YamlTUI_Quit -or $script:YamlTUI_Home)) {
            $running = $false
        }
    }
}

# -- Key action resolver + footer builder -------------------------------------

function Assert-KeyBindings {
    # Validates a key bindings hashtable before the menu starts.
    # Throws a descriptive error for any of these problems:
    #   - Unknown action name (typo guard)
    #   - Invalid value type (must be ConsoleKey, single-char string, or array of those)
    #   - Multi-character string (only single chars are readable as key presses)
    #   - Duplicate key assigned to more than one action (would make one action unreachable)
    param([hashtable]$Bindings)

    $validActions = @('Up', 'Down', 'Select', 'Back', 'Quit', 'Home')

    # Collect every (action, normalised-key) pair for duplicate detection.
    # Normalised form: ConsoleKey enum name (uppercase) or single uppercase char.
    $seen = @{}   # normalised-key -> action name first seen

    foreach ($actionName in $Bindings.Keys) {
        # Unknown action guard
        if ($validActions -notcontains $actionName) {
            throw "KeyBindings: '$actionName' is not a recognised action. Valid actions: $($validActions -join ', ')."
        }

        $candidates = @($Bindings[$actionName])

        foreach ($c in $candidates) {
            # Type guard
            if ($c -isnot [System.ConsoleKey] -and $c -isnot [string] -and $c -isnot [char]) {
                throw "KeyBindings: Action '$actionName' contains an invalid binding type '$($c.GetType().Name)'. Use a [System.ConsoleKey] enum value or a single-character string."
            }

            # Multi-char string guard
            if (($c -is [string] -or $c -is [char]) -and [string]$c -and ([string]$c).Length -ne 1) {
                throw "KeyBindings: Action '$actionName' has binding '$c' - only single-character strings are valid. Use [System.ConsoleKey] for special keys like Enter or Escape."
            }

            # Build normalised key label for duplicate check
            $norm = if ($c -is [System.ConsoleKey]) { $c.ToString().ToUpper() } else { ([string]$c).ToUpper() }

            if ($seen.ContainsKey($norm)) {
                throw "KeyBindings: Key '$norm' is assigned to both '$($seen[$norm])' and '$actionName'. Each key may only be bound to one action."
            }
            $seen[$norm] = $actionName
        }
    }
}

function Resolve-KeyAction {
    # Maps a ConsoleKeyInfo to a named action from the bindings hashtable.
    # Supports [System.ConsoleKey] enum values for special keys and single-char
    # [string] values for letter keys. Each binding value can be a scalar or an
    # array to allow multiple triggers per action (e.g. Back = @(Escape, 'B')).
    param(
        [System.ConsoleKeyInfo]$Key,
        [hashtable]$Bindings
    )
    foreach ($actionName in $Bindings.Keys) {
        $candidates = @($Bindings[$actionName])
        foreach ($c in $candidates) {
            if ($c -is [System.ConsoleKey] -and $Key.Key -eq $c) { return $actionName }
            if (($c -is [string] -or $c -is [char]) -and
                $Key.KeyChar -ne [char]0 -and
                [string]$Key.KeyChar -ieq [string]$c) { return $actionName }
        }
    }
    return $null
}

function Get-FooterText {
    # Builds the footer hint line from the key bindings hashtable.
    # Takes the first binding per action and formats it as a bracketed key name.
    # In index mode, Up/Down/Select are excluded -- only Back/Home/Quit are shown.
    param(
        [hashtable]$Bindings,
        [switch]$IndexNavigation
    )

    $fmtKey = {
        param($val)
        $first = if ($val -is [array]) { $val[0] } else { $val }
        if ($first -is [System.ConsoleKey]) {
            if ($first -eq [System.ConsoleKey]::UpArrow) { 'Up' }
            elseif ($first -eq [System.ConsoleKey]::DownArrow) { 'Dn' }
            elseif ($first -eq [System.ConsoleKey]::Enter) { 'Enter' }
            elseif ($first -eq [System.ConsoleKey]::Escape) { 'Esc' }
            else { "$first" }
        }
        else { [string]$first }
    }

    $up = if ($Bindings.ContainsKey('Up')) { & $fmtKey $Bindings['Up'] }     else { 'Up' }
    $dn = if ($Bindings.ContainsKey('Down')) { & $fmtKey $Bindings['Down'] }   else { 'Dn' }
    $sel = if ($Bindings.ContainsKey('Select')) { & $fmtKey $Bindings['Select'] } else { 'Enter' }
    $bk = if ($Bindings.ContainsKey('Back')) { & $fmtKey $Bindings['Back'] }   else { 'Esc' }
    $hm = if ($Bindings.ContainsKey('Home')) { & $fmtKey $Bindings['Home'] }   else { 'H' }
    $qt = if ($Bindings.ContainsKey('Quit')) { & $fmtKey $Bindings['Quit'] }   else { 'Q' }

    if ($IndexNavigation) {
        return "[$bk] Back  [$hm] Home  [$qt] Quit"
    }
    return "[$up/$dn] Navigate  [$sel] Select  [$bk] Back  [$hm] Home  [$qt] Quit"
}

# -- Rendering dispatcher ------------------------------------------------------

function Write-MenuFrame {
    [CmdletBinding()]
    param(
        [string]$Title,
        [array]$Items,
        [int]$SelectedIndex,
        [string[]]$Breadcrumb,
        [PSCustomObject]$TermProfile,
        [hashtable]$Chars,
        [hashtable]$KeyBindings = @{},

        [Parameter()]
        [hashtable]$StatusData,

        [Parameter(Mandatory)]
        [hashtable]$Theme,

        [switch]$IndexNavigation
    )

    # Inner width = full line width minus the two border chars.
    # Cap to avoid overflow; ensure a sensible minimum.
    $innerWidth = [Math]::Max(38, [Math]::Min($TermProfile.Width - 4, 96))

    $footerText = Get-FooterText -Bindings $KeyBindings -IndexNavigation:$IndexNavigation

    Clear-ConsoleSafe -TermProfile $TermProfile

    if ($TermProfile.UseAnsi) {
        # Tier 3: build complete ANSI frame string, write in one call
        $frame = Build-AnsiFrame -Title $Title -Items $Items -SelectedIndex $SelectedIndex `
            -Breadcrumb $Breadcrumb -InnerWidth $innerWidth -Chars $Chars -FooterText $footerText `
            -IndexNavigation:$IndexNavigation -StatusData $StatusData -Theme $Theme
        [Console]::Write($frame)
        # Erase from cursor to end of screen -- clears leftover lines from a previously
        # taller frame (e.g. description line removed) and any script output below the frame.
        [Console]::Write("$([char]27)[J")
    }
    else {
        # Tier 1/2: build plain-text lines with color hints, then emit via Write-Host
        $lines = Build-HostLines -Title $Title -Items $Items -SelectedIndex $SelectedIndex `
            -Breadcrumb $Breadcrumb -InnerWidth $innerWidth -Chars $Chars -FooterText $footerText `
            -IndexNavigation:$IndexNavigation -StatusData $StatusData -Theme $Theme
        foreach ($line in $lines) {
            # Segmented lines (e.g. status rows) need per-segment color calls
            if ($null -ne $line.Segments) {
                foreach ($seg in $line.Segments) {
                    if ($null -ne $seg.Color) {
                        Write-Host $seg.Text -ForegroundColor $seg.Color -NoNewline
                    }
                    else {
                        Write-Host $seg.Text -NoNewline
                    }
                }
                Write-Host ''
            }
            elseif ($null -ne $line.Color) {
                Write-Host $line.Text -ForegroundColor $line.Color
            }
            else {
                Write-Host $line.Text
            }
        }
    }
}

# -- Shared frame-building helpers ---------------------------------------------

function Get-HRule {
    # Returns a full horizontal rule line (top/mid/bottom separators)
    param([string]$Left, [string]$Right, [int]$InnerWidth, [hashtable]$Chars)
    return "$Left$($Chars.Horizontal * $InnerWidth)$Right"
}

function Get-TruncatedLabel {
    # Truncates a string to maxLen, adding '...' ellipsis if needed
    param([string]$Text, [int]$MaxLen)
    if ($Text.Length -le $MaxLen) { return $Text }
    if ($MaxLen -le 3) { return '...' }
    return $Text.Substring(0, $MaxLen - 3) + '...'
}

# -- Tier 3: ANSI frame builder ------------------------------------------------

function Get-AnsiCode {
    # Converts a ConsoleColor name to an ANSI foreground escape sequence.
    # Empty/null input returns the reset code (terminal default foreground).
    # -Bold prepends the bold attribute for emphasis (title, selected item).
    param(
        [string]$Color,
        [char]$Esc,
        [switch]$Bold
    )
    $code = switch ($Color) {
        'Black' { '30' }
        'DarkBlue' { '34' }
        'DarkGreen' { '32' }
        'DarkCyan' { '36' }
        'DarkRed' { '31' }
        'DarkMagenta' { '35' }
        'DarkYellow' { '33' }
        'Gray' { '37' }
        'DarkGray' { '90' }
        'Blue' { '94' }
        'Green' { '92' }
        'Cyan' { '96' }
        'Red' { '91' }
        'Magenta' { '95' }
        'Yellow' { '93' }
        'White' { '97' }
        default { '' }
    }
    if ([string]::IsNullOrEmpty($Color) -or $code -eq '') {
        return "${Esc}[0m"
    }
    if ($Bold) { return "${Esc}[1;${code}m" }
    return "${Esc}[${code}m"
}

function Get-AnsiItemLine {
    # Builds the bordered ANSI string for one menu item. No newline appended.
    # Shared between Build-AnsiFrame (full render) and Write-AnsiNavUpdate (partial nav).
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [PSCustomObject]$Item,
        [bool]$IsSelected,
        [int]$ItemIndex,
        [int]$ItemCount,
        [switch]$IndexNavigation,
        [int]$ContentWidth,
        [hashtable]$Chars,
        [string]$AbrdrCode,
        [string]$AitemCode,
        [string]$AselCode,
        [string]$AhkCode,
        [string]$RstCode
    )

    $suffixVis = ''
    if ($Item.NodeType -eq 'BRANCH') { $suffixVis += " $($Chars.Arrow)" }
    if (-not $IndexNavigation -and $null -ne $Item.Hotkey) { $suffixVis += " [$($Item.Hotkey.ToUpper())]" }

    if ($IndexNavigation) {
        $indexPrefixLen = if ($ItemCount -ge 10) { 4 } else { 3 }
        $indexPrefix    = if ($ItemCount -ge 10) { "$($ItemIndex + 1). ".PadLeft(4) } else { "$($ItemIndex + 1). " }
        $maxLabelLen    = $ContentWidth - $indexPrefixLen - $suffixVis.Length
        $labelVis       = Get-TruncatedLabel -Text $Item.Label -MaxLen $maxLabelLen
        $itemVisRaw     = "$indexPrefix$labelVis$suffixVis"
        $styledSuffix   = if ($suffixVis -ne '') { "$AhkCode$suffixVis$RstCode" } else { '' }
        $styledItem     = "$AhkCode$indexPrefix$RstCode$AitemCode$labelVis$RstCode$styledSuffix"
    }
    else {
        $selector    = if ($IsSelected) { $Chars.Selected } else { ' ' }
        $maxLabelLen = $ContentWidth - 2 - $suffixVis.Length
        $labelVis    = Get-TruncatedLabel -Text $Item.Label -MaxLen $maxLabelLen
        $itemVisRaw  = "$selector $labelVis$suffixVis"

        if ($IsSelected) {
            $styledSuffix = if ($suffixVis -ne '') { "$AhkCode$suffixVis$RstCode" } else { '' }
            $styledItem   = "$AselCode$selector$RstCode $AselCode$labelVis$RstCode$styledSuffix"
        }
        else {
            $styledSuffix = if ($suffixVis -ne '') { "$AhkCode$suffixVis$RstCode" } else { '' }
            $styledItem   = "  $AitemCode$labelVis$RstCode$styledSuffix"
        }
    }

    $pad = [Math]::Max(0, $ContentWidth - $itemVisRaw.Length)
    return "$AbrdrCode$($Chars.Vertical)$RstCode $styledItem$(' ' * $pad) $AbrdrCode$($Chars.Vertical)$RstCode"
}

function Build-AnsiFrame {
    [CmdletBinding()]
    param(
        [string]$Title,
        [array]$Items,
        [int]$SelectedIndex,
        [string[]]$Breadcrumb,
        [int]$InnerWidth,
        [hashtable]$Chars,
        [string]$FooterText = '[Up/Dn] Navigate  [Enter] Select  [Esc] Back  [H] Home  [Q] Quit',

        [Parameter()]
        [hashtable]$StatusData,

        [Parameter(Mandatory)]
        [hashtable]$Theme,

        [switch]$IndexNavigation
    )

    $esc = [char]27
    $rst = "${esc}[0m"

    # Resolve theme colors to ANSI codes once -- Title and ItemSelected get bold for emphasis
    $abrdr = Get-AnsiCode -Color $Theme.Border          -Esc $esc
    $atitle = Get-AnsiCode -Color $Theme.Title           -Esc $esc -Bold
    $acrumb = Get-AnsiCode -Color $Theme.Breadcrumb      -Esc $esc
    $aitem = Get-AnsiCode -Color $Theme.ItemDefault     -Esc $esc
    $asel = Get-AnsiCode -Color $Theme.ItemSelected    -Esc $esc -Bold
    $ahk = Get-AnsiCode -Color $Theme.ItemHotkey      -Esc $esc
    $adesc = Get-AnsiCode -Color $Theme.ItemDescription -Esc $esc
    $aslbl = Get-AnsiCode -Color $Theme.StatusLabel     -Esc $esc
    $asval = Get-AnsiCode -Color $Theme.StatusValue     -Esc $esc
    $aftr = Get-AnsiCode -Color $Theme.FooterText      -Esc $esc

    $sb = [System.Text.StringBuilder]::new()

    # Inline helper: build a bordered content line.
    # All values are explicit params — no outer-scope capture.
    $mkLine = {
        param([string]$VisText, [string]$StyledText, [int]$Cw, [hashtable]$CharSet, [string]$CynCode, [string]$RstCode)
        $pad = [Math]::Max(0, $Cw - $VisText.Length)
        "$CynCode$($CharSet.Vertical)$RstCode $StyledText$(' ' * $pad) $CynCode$($CharSet.Vertical)$RstCode"
    }

    # ESC[K (erase to end of line) before every newline clears any terminal content
    # that sits to the right of the frame when the window is wider than the frame.
    $nl = "${esc}[K$([System.Environment]::NewLine)"
    $cw = $InnerWidth - 2

    # -- Top border -------------------------------------------------------------
    $null = $sb.Append("$abrdr$(Get-HRule $Chars.TopLeft $Chars.TopRight $InnerWidth $Chars)$rst$nl")

    # -- Title ------------------------------------------------------------------
    $titleVis = Get-TruncatedLabel -Text $Title -MaxLen $cw
    $null = $sb.Append((& $mkLine $titleVis "$atitle$titleVis$rst" $cw $Chars $abrdr $rst) + $nl)

    # -- Breadcrumb (only when navigated at least one level deep) ---------------
    if ($Breadcrumb -and $Breadcrumb.Count -gt 0) {
        $crumbVis = ($Breadcrumb -join " $($Chars.Arrow) ")
        $crumbVis = Get-TruncatedLabel -Text $crumbVis -MaxLen $cw
        $null = $sb.Append((& $mkLine $crumbVis "$acrumb$crumbVis$rst" $cw $Chars $abrdr $rst) + $nl)
    }

    # -- Separator --------------------------------------------------------------
    $null = $sb.Append("$abrdr$(Get-HRule $Chars.LeftT $Chars.RightT $InnerWidth $Chars)$rst$nl")

    # -- Empty line -------------------------------------------------------------
    $null = $sb.Append((& $mkLine '' '' $cw $Chars $abrdr $rst) + $nl)

    # -- Items ------------------------------------------------------------------
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $item = $Items[$i]
        $isSelected = ($i -eq $SelectedIndex)

        $null = $sb.Append((Get-AnsiItemLine -Item $item -IsSelected $isSelected `
            -ItemIndex $i -ItemCount $Items.Count -IndexNavigation:$IndexNavigation `
            -ContentWidth $cw -Chars $Chars `
            -AbrdrCode $abrdr -AitemCode $aitem -AselCode $asel -AhkCode $ahk -RstCode $rst) + $nl)

        # Description sub-line for selected item only (suppressed in index mode)
        if (-not $IndexNavigation -and $isSelected -and $null -ne $item.Description) {
            $descPfx = '   '
            $descVis = $descPfx + (Get-TruncatedLabel -Text $item.Description -MaxLen ($cw - $descPfx.Length))
            $null = $sb.Append((& $mkLine $descVis "$adesc$descVis$rst" $cw $Chars $abrdr $rst) + $nl)
        }
    }

    # -- Empty line -------------------------------------------------------------
    $null = $sb.Append((& $mkLine '' '' $cw $Chars $abrdr $rst) + $nl)

    # -- Status bar (optional, only when StatusData has at least one entry) -----
    if ($null -ne $StatusData -and $StatusData.Count -gt 0) {
        # Find the longest label to align the value column
        $maxLblLen = 0
        foreach ($k in $StatusData.Keys) {
            if ($k.Length -gt $maxLblLen) { $maxLblLen = $k.Length }
        }
        # Cap label column at half of content width so values always have space
        $maxLblLen = [Math]::Min($maxLblLen, [Math]::Floor($cw / 2))
        $valMaxLen = [Math]::Max(1, $cw - $maxLblLen - 2)

        $null = $sb.Append("$abrdr$(Get-HRule $Chars.LeftT $Chars.RightT $InnerWidth $Chars)$rst$nl")

        foreach ($k in $StatusData.Keys) {
            $lblVis = (Get-TruncatedLabel -Text $k -MaxLen $maxLblLen).PadRight($maxLblLen)
            $valVis = Get-TruncatedLabel -Text ([string]$StatusData[$k]) -MaxLen $valMaxLen
            $rowVis = "$lblVis  $valVis"
            $rowStyled = "$aslbl$lblVis$rst  $asval$valVis$rst"
            $null = $sb.Append((& $mkLine $rowVis $rowStyled $cw $Chars $abrdr $rst) + $nl)
        }
    }

    # -- Footer separator -------------------------------------------------------
    $null = $sb.Append("$abrdr$(Get-HRule $Chars.LeftT $Chars.RightT $InnerWidth $Chars)$rst$nl")

    # -- Footer content ---------------------------------------------------------
    $footVis = $FooterText
    $footVis = Get-TruncatedLabel -Text $footVis -MaxLen $cw
    $null = $sb.Append((& $mkLine $footVis "$aftr$footVis$rst" $cw $Chars $abrdr $rst) + $nl)

    # -- Bottom border ----------------------------------------------------------
    $null = $sb.Append("$abrdr$(Get-HRule $Chars.BottomLeft $Chars.BottomRight $InnerWidth $Chars)$rst$nl")

    return $sb.ToString()
}

# -- ANSI partial navigation update -------------------------------------------

function Write-AnsiNavUpdate {
    # Rewrites only the two item lines that change on Up/Down navigation.
    # Only called on the ANSI path when neither item has a description (row offsets are stable).
    [CmdletBinding()]
    param(
        [array]$Items,
        [int]$PrevIdx,
        [int]$NewIdx,
        [string[]]$Breadcrumb,
        [int]$InnerWidth,
        [hashtable]$Chars,

        [Parameter(Mandatory)]
        [hashtable]$Theme
    )

    $esc = [char]27
    $rst = "${esc}[0m"

    $abrdr = Get-AnsiCode -Color $Theme.Border       -Esc $esc
    $aitem = Get-AnsiCode -Color $Theme.ItemDefault  -Esc $esc
    $asel  = Get-AnsiCode -Color $Theme.ItemSelected -Esc $esc -Bold
    $ahk   = Get-AnsiCode -Color $Theme.ItemHotkey   -Esc $esc

    $cw = $InnerWidth - 2
    # Lines before first item: top-border + title + [breadcrumb] + separator + empty-line
    $headerLines = if ($null -ne $Breadcrumb -and $Breadcrumb.Count -gt 0) { 5 } else { 4 }

    $sb = [System.Text.StringBuilder]::new()

    foreach ($updateIdx in @($PrevIdx, $NewIdx)) {
        $ansiRow    = $headerLines + 1 + $updateIdx
        $isSelected = ($updateIdx -eq $NewIdx)
        $line = Get-AnsiItemLine -Item $Items[$updateIdx] -IsSelected $isSelected `
            -ItemIndex $updateIdx -ItemCount $Items.Count `
            -ContentWidth $cw -Chars $Chars `
            -AbrdrCode $abrdr -AitemCode $aitem -AselCode $asel -AhkCode $ahk -RstCode $rst
        $null = $sb.Append("${esc}[$ansiRow;1H$line${esc}[K")
    }

    [Console]::Write($sb.ToString())
}

# -- Tier 1/2: Write-Host line builder ----------------------------------------

function Build-HostLines {
    [CmdletBinding()]
    param(
        [string]$Title,
        [array]$Items,
        [int]$SelectedIndex,
        [string[]]$Breadcrumb,
        [int]$InnerWidth,
        [hashtable]$Chars,
        [string]$FooterText = '[Up/Dn] Navigate  [Enter] Select  [Esc] Back  [H] Home  [Q] Quit',

        [Parameter()]
        [hashtable]$StatusData,

        [Parameter(Mandatory)]
        [hashtable]$Theme,

        [switch]$IndexNavigation
    )

    $lines = [System.Collections.Generic.List[hashtable]]::new()
    $cw = $InnerWidth - 2  # content width (minus left/right margins)

    # Helper: returns a segment-based bordered line so border glyphs can keep
    # the border color even when content uses a different color.
    # $Cw and $CharSet are passed explicitly to avoid PS5.1 scoping issues.
    $mkLine = {
        param([string]$Text, $Color, [int]$Cw, [hashtable]$CharSet, $BorderColor)
        $truncated = Get-TruncatedLabel -Text $Text -MaxLen $Cw
        @{
            Segments = @(
                @{ Text = "$($CharSet.Vertical) "; Color = $BorderColor }
                @{ Text = $truncated.PadRight($Cw); Color = $Color }
                @{ Text = " $($CharSet.Vertical)"; Color = $BorderColor }
            )
        }
    }

    # Resolve theme colors -- $null means Write-Host uses the terminal default
    $cBorder = $Theme.Border
    $cTitle = if ([string]::IsNullOrEmpty($Theme.Title)) { $null } else { $Theme.Title }
    $cCrumb = if ([string]::IsNullOrEmpty($Theme.Breadcrumb)) { $null } else { $Theme.Breadcrumb }
    $cItem = if ([string]::IsNullOrEmpty($Theme.ItemDefault)) { $null } else { $Theme.ItemDefault }
    $cSel = if ([string]::IsNullOrEmpty($Theme.ItemSelected)) { $null } else { $Theme.ItemSelected }
    $cDesc = if ([string]::IsNullOrEmpty($Theme.ItemDescription)) { $null } else { $Theme.ItemDescription }
    $cSlbl = if ([string]::IsNullOrEmpty($Theme.StatusLabel)) { $null } else { $Theme.StatusLabel }
    $cSval = if ([string]::IsNullOrEmpty($Theme.StatusValue)) { $null } else { $Theme.StatusValue }
    $cFtr = if ([string]::IsNullOrEmpty($Theme.FooterText)) { $null } else { $Theme.FooterText }

    # Top border
    $lines.Add(@{ Text = (Get-HRule $Chars.TopLeft $Chars.TopRight $InnerWidth $Chars); Color = $cBorder })

    # Title
    $lines.Add((& $mkLine $Title $cTitle $cw $Chars $cBorder))

    # Breadcrumb
    if ($Breadcrumb -and $Breadcrumb.Count -gt 0) {
        $crumbText = $Breadcrumb -join " $($Chars.Arrow) "
        $lines.Add((& $mkLine $crumbText $cCrumb $cw $Chars $cBorder))
    }

    # Separator
    $lines.Add(@{ Text = (Get-HRule $Chars.LeftT $Chars.RightT $InnerWidth $Chars); Color = $cBorder })

    # Empty line
    $lines.Add((& $mkLine '' $null $cw $Chars $cBorder))

    # Items
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $item = $Items[$i]
        $isSelected = ($i -eq $SelectedIndex)

        $selector = if ($isSelected) { $Chars.Selected } else { ' ' }
        $suffixVis = ''
        if ($item.NodeType -eq 'BRANCH') { $suffixVis += " $($Chars.Arrow)" }
        if (-not $IndexNavigation -and $null -ne $item.Hotkey) { $suffixVis += " [$($item.Hotkey.ToUpper())]" }

        if ($IndexNavigation) {
            $indexPrefixLen = if ($Items.Count -ge 10) { 4 } else { 3 }
            $indexPrefix = if ($Items.Count -ge 10) { "$($i+1). ".PadLeft(4) } else { "$($i+1). " }
            $maxLabelLen = $cw - $indexPrefixLen - $suffixVis.Length
            $labelVis = Get-TruncatedLabel -Text $item.Label -MaxLen $maxLabelLen
            $lineText = "$indexPrefix$labelVis$suffixVis"
        }
        else {
            $maxLabelLen = $cw - 2 - $suffixVis.Length
            $labelVis = Get-TruncatedLabel -Text $item.Label -MaxLen $maxLabelLen
            $lineText = "$selector $labelVis$suffixVis"
        }

        # No selected highlight in index mode -- selection is implicit in the number typed.
        $color = if ($isSelected -and -not $IndexNavigation) { $cSel } else { $cItem }
        $lines.Add((& $mkLine $lineText $color $cw $Chars $cBorder))

        # Description for selected item (suppressed in index mode)
        if (-not $IndexNavigation -and $isSelected -and $null -ne $item.Description) {
            $descText = '   ' + $item.Description
            $lines.Add((& $mkLine $descText $cDesc $cw $Chars $cBorder))
        }
    }

    # Empty line
    $lines.Add((& $mkLine '' $null $cw $Chars $cBorder))

    # Status bar (optional, only when StatusData has at least one entry)
    if ($null -ne $StatusData -and $StatusData.Count -gt 0) {
        # Find the longest label to align the value column
        $maxLblLen = 0
        foreach ($k in $StatusData.Keys) {
            if ($k.Length -gt $maxLblLen) { $maxLblLen = $k.Length }
        }
        # Cap label column at half content width so the value column always has space
        $maxLblLen = [Math]::Min($maxLblLen, [Math]::Floor($cw / 2))
        $valMaxLen = [Math]::Max(1, $cw - $maxLblLen - 2)

        $lines.Add(@{ Text = (Get-HRule $Chars.LeftT $Chars.RightT $InnerWidth $Chars); Color = $cBorder })

        foreach ($k in $StatusData.Keys) {
            $lblVis = (Get-TruncatedLabel -Text $k -MaxLen $maxLblLen).PadRight($maxLblLen)
            $valVis = Get-TruncatedLabel -Text ([string]$StatusData[$k]) -MaxLen $valMaxLen
            $trailing = ' ' * [Math]::Max(0, $cw - $maxLblLen - 2 - $valVis.Length)
            # Segment-based line: label and value use separate theme colors
            $lines.Add(@{
                    Segments = @(
                        @{ Text = "$($Chars.Vertical) "; Color = $cBorder },
                        @{ Text = $lblVis; Color = $cSlbl },
                        @{ Text = '  '; Color = $null },
                        @{ Text = $valVis; Color = $cSval },
                        @{ Text = "$trailing $($Chars.Vertical)"; Color = $cBorder }
                    )
                })
        }
    }

    # Footer separator
    $lines.Add(@{ Text = (Get-HRule $Chars.LeftT $Chars.RightT $InnerWidth $Chars); Color = $cBorder })

    # Footer
    $footText = $FooterText
    $lines.Add((& $mkLine $footText $cFtr $cw $Chars $cBorder))

    # Bottom border
    $lines.Add(@{ Text = (Get-HRule $Chars.BottomLeft $Chars.BottomRight $InnerWidth $Chars); Color = $cBorder })

    return $lines.ToArray()
}

# -- Action banner ------------------------------------------------------------

function Write-BorderedText {
    <#
    .SYNOPSIS
        Renders a bordered box with optional title, description, and text wrapping.
    .DESCRIPTION
        Draws a top border, one or more content lines, and a bottom border using the
        same character set as the menu frame. Text longer than the box inner width is
        wrapped automatically. An optional title is embedded in the top border.
        Optional details text is rendered below the main text in a dimmer color,
        separated by a horizontal rule, and also wraps automatically.
        Colors are sourced from the active theme. Intended to be called immediately
        after Clear-ConsoleSafe in the leaf-node execution block so the user can see
        which action is running before any script output appears.
    .PARAMETER Text
        The primary text to display inside the box. Long lines are wrapped automatically.
    .PARAMETER Title
        Optional title embedded in the top border line.
    .PARAMETER Details
        Optional secondary text rendered below the main text, separated by a divider.
        Long lines are wrapped automatically. Displayed in DetailsColor.
    .PARAMETER BorderColor
        ConsoleColor name for the box-drawing characters. Defaults to DarkCyan.
        Pass an empty string to use the terminal default color.
    .PARAMETER TextColor
        ConsoleColor name for the primary text inside the box. Defaults to White.
        Pass an empty string to use the terminal default color.
    .PARAMETER DetailsColor
        ConsoleColor name for the details text. Defaults to DarkGray.
        Pass an empty string to use the terminal default color.
    .PARAMETER MaxWidth
        Total box width including the two border characters. Defaults to 80.
        Automatically clamped to the current console window width so the box never
        overflows. When details text is present the minimum inner width is wider
        (60 chars) so the text has room to breathe.
    .PARAMETER Chars
        Character set hashtable from Get-CharacterSet. Supplies the correct border
        glyphs for the active border style (Unicode or ASCII).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter()]
        [string]$Title = '',

        [Parameter()]
        [string]$Details = '',

        [Parameter()]
        [AllowEmptyString()]
        [string]$BorderColor = 'DarkCyan',

        [Parameter()]
        [AllowEmptyString()]
        [string]$TextColor = 'White',

        [Parameter()]
        [AllowEmptyString()]
        [string]$DetailsColor = 'DarkGray',

        [Parameter()]
        [ValidateRange(20, 500)]
        [int]$MaxWidth = 80,

        [Parameter(Mandatory)]
        [hashtable]$Chars
    )

    # Normalize empty-string theme colors to $null so Write-Host receives no
    # -ForegroundColor argument rather than an invalid empty-string color name.
    $cBorder = if ([string]::IsNullOrEmpty($BorderColor)) { $null } else { $BorderColor }
    $cText = if ([string]::IsNullOrEmpty($TextColor)) { $null } else { $TextColor }
    $cDesc = if ([string]::IsNullOrEmpty($DetailsColor)) { $null } else { $DetailsColor }

    # Helper: wrap a string into lines no longer than $width visible characters.
    function Invoke-WordWrap {
        param([string]$Content, [int]$Width)
        $out = [System.Collections.Generic.List[string]]::new()
        foreach ($rawLine in ($Content -split "`n")) {
            $remaining = $rawLine
            while (($remaining -replace '\x1b\[[0-9;]*m', '').Length -gt $Width) {
                # Find the last space within the width limit to break on a word boundary.
                # Fall back to a hard cut only when no space exists (e.g. a single long word).
                $candidate = $remaining.Substring(0, $Width)
                $breakAt = $candidate.LastIndexOf(' ')
                if ($breakAt -le 0) {
                    # No space found -- hard cut is the only option.
                    $out.Add($candidate)
                    $remaining = $remaining.Substring($Width)
                }
                else {
                    $out.Add($remaining.Substring(0, $breakAt))
                    $remaining = $remaining.Substring($breakAt + 1)  # +1 skips the space itself
                }
            }
            $out.Add($remaining)
        }
        return $out
    }

    # Helper: write one padded content row.
    function Write-ContentLine {
        param([string]$Line, [int]$InnerWidth, $LineColor)
        $visLen = ($Line -replace '\x1b\[[0-9;]*m', '').Length
        $padRight = $InnerWidth - 2 - $visLen
        $left = $Chars.Vertical + ' '
        $right = (' ' * $padRight) + ' ' + $Chars.Vertical
        if ($null -ne $cBorder) { Write-Host -Object $left  -NoNewline -ForegroundColor $cBorder } else { Write-Host -Object $left  -NoNewline }
        if ($null -ne $LineColor) { Write-Host -Object $Line -NoNewline -ForegroundColor $LineColor } else { Write-Host -Object $Line -NoNewline }
        if ($null -ne $cBorder) { Write-Host -Object $right -ForegroundColor $cBorder } else { Write-Host -Object $right }
    }

    # Total box width = $innerWidth + 2 border chars.
    # Clamp MaxWidth to the console width so the box never overflows the terminal.
    $consoleWidth = $Host.UI.RawUI.WindowSize.Width
    $effectiveMax = [Math]::Min($MaxWidth, $consoleWidth) - 2  # convert to inner width

    # Use a wider minimum when details text is present so it has room to breathe;
    # a narrow box with long details produces very tall, cramped output.
    $hasDetails = -not [string]::IsNullOrEmpty($Details)
    $minInner = if ($hasDetails) { 58 } else { 38 }

    # Establish the final inner width before any wrapping:
    # must fit the title, respect the minimum, never exceed the effective maximum.
    $titleLen = ($Title -replace '\x1b\[[0-9;]*m', '').Length
    $innerWidth = [Math]::Max($minInner, $titleLen + 4)
    $innerWidth = [Math]::Min($innerWidth, $effectiveMax)

    # Wrap width = inner width minus the two side-padding spaces (one each side).
    # Because the width is fixed before wrapping, content fills the full available space.
    $wrapWidth = $innerWidth - 2
    $wrappedText = Invoke-WordWrap -Content $Text -Width $wrapWidth
    $wrappedDesc = if ($hasDetails) {
        Invoke-WordWrap -Content $Details -Width $wrapWidth
    }
    else {
        [System.Collections.Generic.List[string]]::new()
    }

    # Build top border -- embed title when provided.
    if ([string]::IsNullOrEmpty($Title)) {
        $top = $Chars.TopLeft + ($Chars.Horizontal * $innerWidth) + $Chars.TopRight
    }
    else {
        $dashCount = $innerWidth - $titleLen - 2
        $top = $Chars.TopLeft + ' ' + $Title + ' ' + ($Chars.Horizontal * $dashCount) + $Chars.TopRight
    }
    $bottom = $Chars.BottomLeft + ($Chars.Horizontal * $innerWidth) + $Chars.BottomRight
    $divider = $Chars.LeftT + ($Chars.Horizontal * $innerWidth) + $Chars.RightT

    # Write top border.
    if ($null -ne $cBorder) { Write-Host -Object $top -ForegroundColor $cBorder } else { Write-Host -Object $top }

    # Write primary text lines.
    foreach ($line in $wrappedText) {
        Write-ContentLine -Line $line -InnerWidth $innerWidth -LineColor $cText
    }

    # Write divider + description lines when description is present.
    if ($wrappedDesc.Count -gt 0) {
        if ($null -ne $cBorder) { Write-Host -Object $divider -ForegroundColor $cBorder } else { Write-Host -Object $divider }
        foreach ($line in $wrappedDesc) {
            Write-ContentLine -Line $line -InnerWidth $innerWidth -LineColor $cDesc
        }
    }

    # Write bottom border.
    if ($null -ne $cBorder) { Write-Host -Object $bottom -ForegroundColor $cBorder } else { Write-Host -Object $bottom }
}

