function Read-ConsoleKey {
    <#
    .SYNOPSIS
        Thin wrapper around [Console]::ReadKey so tests can mock it.
    #>
    [CmdletBinding()]
    [OutputType([System.ConsoleKeyInfo])]
    param()
    return [Console]::ReadKey($true)
}

function Clear-ConsoleSafe {
    [CmdletBinding()]
    param()

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
        [hashtable]$Theme
    )

    $items = $MenuData.Items
    $title = $MenuData.Title
    $idx = 0
    $running = $true

    while ($running) {
        # Home signal: at root we stay and re-render; elsewhere we bubble up
        if ($IsRoot -and $script:YamlTUI_Home) { $script:YamlTUI_Home = $false }

        # Render the full frame
        Write-MenuFrame -Title $title -Items $items -SelectedIndex $idx `
            -Breadcrumb $Breadcrumb -TermProfile $TermProfile -Chars $Chars -KeyBindings $KeyBindings `
            -StatusData $StatusData -Theme $Theme

        $key = Read-ConsoleKey

        $action = Resolve-KeyAction -Key $key -Bindings $KeyBindings

        switch ($action) {
            'Up' {
                if ($idx -gt 0) { $idx-- } else { $idx = $items.Count - 1 }
            }
            'Down' {
                if ($idx -lt ($items.Count - 1)) { $idx++ } else { $idx = 0 }
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
                            Clear-ConsoleSafe
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
                            Clear-ConsoleSafe
                            Write-Host ''
                            Write-Host "  Hook error: $_" -ForegroundColor Red
                            Write-Host ''
                            Write-Host '  Press any key to return to menu...' -ForegroundColor $Theme.FooterText
                            $null = Read-ConsoleKey
                            $proceed = $false
                        }
                    }

                    if ($proceed -and $sel.Confirm) {
                        Clear-ConsoleSafe
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
                        Clear-ConsoleSafe
                        Write-BorderedText -TextContent "Running: $($sel.Label)" -TextColor $Theme.Title -BorderColor $Theme.Border -Chars $Chars
                        Write-Host ''

                        if ($Timer) {
                            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                        }

                        try {
                            Invoke-MenuAction -Node $sel -RootDir $RootDir
                        }
                        catch {
                            Write-Host "`nError: $_" -ForegroundColor Red
                        }

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
                            Write-BorderedText -TextContent $timerString -TextColor $Theme.Title -BorderColor 'DarkGray' -Chars $Chars
                        }

                        Write-Host ''
                        Write-Host '  Press any key to return to menu...' -ForegroundColor $Theme.FooterText
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
    param([hashtable]$Bindings)

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
        [hashtable]$Theme
    )

    # Inner width = full line width minus the two border chars.
    # Cap to avoid overflow; ensure a sensible minimum.
    $innerWidth = [Math]::Max(38, [Math]::Min($TermProfile.Width - 4, 96))

    $footerText = Get-FooterText -Bindings $KeyBindings

    Clear-ConsoleSafe

    if ($TermProfile.UseAnsi) {
        # Tier 3: build complete ANSI frame string, write in one call
        $frame = Build-AnsiFrame -Title $Title -Items $Items -SelectedIndex $SelectedIndex `
            -Breadcrumb $Breadcrumb -InnerWidth $innerWidth -Chars $Chars -FooterText $footerText `
            -StatusData $StatusData -Theme $Theme
        [Console]::Write($frame)
    }
    else {
        # Tier 1/2: build plain-text lines with color hints, then emit via Write-Host
        $lines = Build-HostLines -Title $Title -Items $Items -SelectedIndex $SelectedIndex `
            -Breadcrumb $Breadcrumb -InnerWidth $innerWidth -Chars $Chars -FooterText $footerText `
            -StatusData $StatusData -Theme $Theme
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
        [hashtable]$Theme
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

    $nl = [System.Environment]::NewLine
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

        $selector = if ($isSelected) { $Chars.Selected } else { ' ' }

        # Build suffix (arrow for branch, hotkey hint)
        $suffixVis = ''
        if ($item.NodeType -eq 'BRANCH') { $suffixVis += " $($Chars.Arrow)" }
        if ($null -ne $item.Hotkey) { $suffixVis += " [$($item.Hotkey.ToUpper())]" }

        # Visible: "selector label suffix" inside the " X " margin slots
        # Total visible content: 1(sel) + 1(space) + label + suffix
        $maxLabelLen = $cw - 2 - $suffixVis.Length  # 2 = selector + space
        $labelVis = Get-TruncatedLabel -Text $item.Label -MaxLen $maxLabelLen
        $itemVisRaw = "$selector $labelVis$suffixVis"

        if ($isSelected) {
            $styledSel = "$asel$selector$rst"
            $styledLabel = "$asel$labelVis$rst"
            $styledSuffix = if ($suffixVis -ne '') { "$ahk$suffixVis$rst" } else { '' }
            $styledItem = "$styledSel $styledLabel$styledSuffix"
        }
        else {
            $styledSuffix = if ($suffixVis -ne '') { "$ahk$suffixVis$rst" } else { '' }
            # Two spaces: one for the empty selector slot, one for the space after it
            $styledItem = "  $aitem$labelVis$rst$styledSuffix"
        }

        $null = $sb.Append((& $mkLine $itemVisRaw $styledItem $cw $Chars $abrdr $rst) + $nl)

        # Description sub-line for selected item only
        if ($isSelected -and $null -ne $item.Description) {
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
        [hashtable]$Theme
    )

    $lines = @()
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
    $lines += @{ Text = (Get-HRule $Chars.TopLeft $Chars.TopRight $InnerWidth $Chars); Color = $cBorder }

    # Title
    $lines += (& $mkLine $Title $cTitle $cw $Chars $cBorder)

    # Breadcrumb
    if ($Breadcrumb -and $Breadcrumb.Count -gt 0) {
        $crumbText = $Breadcrumb -join " $($Chars.Arrow) "
        $lines += (& $mkLine $crumbText $cCrumb $cw $Chars $cBorder)
    }

    # Separator
    $lines += @{ Text = (Get-HRule $Chars.LeftT $Chars.RightT $InnerWidth $Chars); Color = $cBorder }

    # Empty line
    $lines += (& $mkLine '' $null $cw $Chars $cBorder)

    # Items
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $item = $Items[$i]
        $isSelected = ($i -eq $SelectedIndex)

        $selector = if ($isSelected) { $Chars.Selected } else { ' ' }
        $suffixVis = ''
        if ($item.NodeType -eq 'BRANCH') { $suffixVis += " $($Chars.Arrow)" }
        if ($null -ne $item.Hotkey) { $suffixVis += " [$($item.Hotkey.ToUpper())]" }

        $maxLabelLen = $cw - 2 - $suffixVis.Length
        $labelVis = Get-TruncatedLabel -Text $item.Label -MaxLen $maxLabelLen
        $lineText = "$selector $labelVis$suffixVis"

        $color = if ($isSelected) { $cSel } else { $cItem }
        $lines += (& $mkLine $lineText $color $cw $Chars $cBorder)

        # Description for selected item
        if ($isSelected -and $null -ne $item.Description) {
            $descText = '   ' + $item.Description
            $lines += (& $mkLine $descText $cDesc $cw $Chars $cBorder)
        }
    }

    # Empty line
    $lines += (& $mkLine '' $null $cw $Chars $cBorder)

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

        $lines += @{ Text = (Get-HRule $Chars.LeftT $Chars.RightT $InnerWidth $Chars); Color = $cBorder }

        foreach ($k in $StatusData.Keys) {
            $lblVis = (Get-TruncatedLabel -Text $k -MaxLen $maxLblLen).PadRight($maxLblLen)
            $valVis = Get-TruncatedLabel -Text ([string]$StatusData[$k]) -MaxLen $valMaxLen
            $trailing = ' ' * [Math]::Max(0, $cw - $maxLblLen - 2 - $valVis.Length)
            # Segment-based line: label and value use separate theme colors
            $lines += @{
                Segments = @(
                    @{ Text = "$($Chars.Vertical) "; Color = $cBorder },
                    @{ Text = $lblVis; Color = $cSlbl },
                    @{ Text = '  '; Color = $null },
                    @{ Text = $valVis; Color = $cSval },
                    @{ Text = "$trailing $($Chars.Vertical)"; Color = $cBorder }
                )
            }
        }
    }

    # Footer separator
    $lines += @{ Text = (Get-HRule $Chars.LeftT $Chars.RightT $InnerWidth $Chars); Color = $cBorder }

    # Footer
    $footText = $FooterText
    $lines += (& $mkLine $footText $cFtr $cw $Chars $cBorder)

    # Bottom border
    $lines += @{ Text = (Get-HRule $Chars.BottomLeft $Chars.BottomRight $InnerWidth $Chars); Color = $cBorder }

    return $lines
}

# -- Action banner ------------------------------------------------------------

function Write-BorderedText {
    <#
    .SYNOPSIS
        Renders a single-line bordered box announcing the currently executing leaf node.
    .DESCRIPTION
        Draws a top border, a content line, and a bottom border using the same character
        set as the menu frame. Colors are sourced from the active theme. Intended to be
        called immediately after Clear-ConsoleSafe in the leaf-node execution block so
        the user can see which action is running before any script output appears.
    .PARAMETER TextContent
        The text to display inside the box (e.g. "Running: My-Script").
    .PARAMETER BorderColor
        ConsoleColor name for the box-drawing characters. Pass $Theme.Border.
    .PARAMETER TextColor
        ConsoleColor name for the text inside the box. Pass $Theme.Title.
    .PARAMETER Chars
        Character set hashtable from Get-CharacterSet. Supplies the correct border
        glyphs for the active border style (Unicode or ASCII).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TextContent,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$BorderColor,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$TextColor,

        [Parameter(Mandatory)]
        [hashtable]$Chars
    )

    # Normalize empty-string theme colors to $null so Write-Host receives no
    # -ForegroundColor argument rather than an invalid empty-string color name.
    $cBorder = if ([string]::IsNullOrEmpty($BorderColor)) { $null } else { $BorderColor }
    $cText = if ([string]::IsNullOrEmpty($TextColor)) { $null } else { $TextColor }

    # Strip ANSI escape sequences before measuring -- the raw string length is
    # inflated by invisible color codes, which throws off padding calculations.
    $visibleLength = ($TextContent -replace '\x1b\[[0-9;]*m', '').Length

    # Inner content width: visible text + 2 leading spaces + at least 4 trailing spaces.
    # Minimum of 40 keeps the box from being too narrow for very short labels.
    $innerWidth = [Math]::Max(40, $visibleLength + 6)
    $padRight = $innerWidth - 2 - $visibleLength

    $top = $Chars.TopLeft + ($Chars.Horizontal * $innerWidth) + $Chars.TopRight
    $bottom = $Chars.BottomLeft + ($Chars.Horizontal * $innerWidth) + $Chars.BottomRight
    $leftEdge = $Chars.Vertical + ' '
    $rightEdge = (' ' * $padRight) + ' ' + $Chars.Vertical

    if ($null -ne $cBorder) {
        Write-Host -Object $top -ForegroundColor $cBorder
        Write-Host -Object $leftEdge -NoNewline -ForegroundColor $cBorder
    }
    else {
        Write-Host -Object $top
        Write-Host -Object $leftEdge -NoNewline
    }

    if ($null -ne $cText) {
        Write-Host -Object $TextContent -NoNewline -ForegroundColor $cText
    }
    else {
        Write-Host -Object $TextContent -NoNewline
    }

    if ($null -ne $cBorder) {
        Write-Host -Object $rightEdge -ForegroundColor $cBorder
        Write-Host -Object $bottom -ForegroundColor $cBorder
    }
    else {
        Write-Host -Object $rightEdge
        Write-Host -Object $bottom
    }
}

