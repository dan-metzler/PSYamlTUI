function Get-TerminalProfile {
    <#
    .SYNOPSIS
        Detects terminal capabilities once at module load and returns a profile object.
    .DESCRIPTION
        Independently detects ANSI escape sequence support and Unicode (UTF-8) support.
        A terminal can have one without the other — they are never assumed together.
    .OUTPUTS
        PSCustomObject with: UseAnsi, UseUnicode, ColorMethod, Width
    #>
    [CmdletBinding()]
    param()

    # -- Unicode Detection ------------------------------------------------------
    # UTF-8 output encoding (CodePage 65001) means PowerShell is piping UTF-8,
    # so box-drawing chars will survive the output pipeline intact.
    # Windows Terminal always renders Unicode regardless of encoding, so we also
    # grant Unicode when WT_SESSION is set even if the codepage hasn't been changed.
    # We also set the output encoding to UTF-8 in that case so that all Unicode
    # characters (not just those in CP437) render correctly via Write-Host.
    $useUnicode = ([Console]::OutputEncoding.CodePage -eq 65001) -or
                  ($null -ne $env:WT_SESSION)

    if ($useUnicode -and [Console]::OutputEncoding.CodePage -ne 65001) {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    }

    # -- ANSI Detection ---------------------------------------------------------
    # Check well-known env vars set by ANSI-capable terminal hosts
    $useAnsi = $false

    if ($null -ne $env:WT_SESSION) {
        # Windows Terminal
        $useAnsi = $true
    }
    elseif ($null -ne $env:COLORTERM) {
        # True-color terminals (iTerm2, most Linux terminals)
        $useAnsi = $true
    }
    elseif ($env:TERM_PROGRAM -eq 'vscode') {
        # VS Code integrated terminal
        $useAnsi = $true
    }
    elseif ($null -ne $env:TERM -and $env:TERM -ne 'dumb') {
        # Unix-style TERM variable (xterm, xterm-256color, etc.)
        $useAnsi = $true
    }
    elseif ($PSVersionTable.PSVersion.Major -ge 7) {
        # PS7+ enables VirtualTerminalProcessing by default on Windows
        $useAnsi = $true
    }

    # -- Width Detection --------------------------------------------------------
    $width = 80
    try {
        $w = [Console]::WindowWidth
        if ($w -gt 0) { $width = $w }
    }
    catch {
        # Fallback already set
    }

    [PSCustomObject]@{
        UseAnsi     = $useAnsi
        UseUnicode  = $useUnicode
        ColorMethod = if ($useAnsi) { 'Ansi' } else { 'WriteHost' }
        Width       = $width
    }
}

