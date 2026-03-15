function Get-ColorTheme {
    <#
    .SYNOPSIS
        Returns a fully resolved color theme hashtable.
    .DESCRIPTION
        Merges the supplied theme hashtable over the built-in Default theme.
        Any key omitted by the caller falls back to the Default value, so
        partial overrides are fully supported.

        All color values must be valid [System.ConsoleColor] names (e.g. 'Cyan',
        'DarkGray'). The special value '' (empty string) for ItemDefault means
        "use the terminal's default foreground color" -- no color code is applied.

        Pass $null or an empty hashtable to get the Default theme unchanged.
    .PARAMETER Theme
        Hashtable of color overrides. All keys are optional.
    .EXAMPLE
        Get-ColorTheme
        # Returns the Default theme.
    .EXAMPLE
        Get-ColorTheme -Theme @{ Border = 'DarkBlue'; ItemSelected = 'Green' }
        # Returns Default theme with Border and ItemSelected overridden.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [hashtable]$Theme
    )

    # Default theme -- these values reproduce the built-in look exactly.
    # ItemDefault = '' means "no explicit color" (terminal's default foreground).
    $defaults = @{
        Border          = 'DarkCyan'
        Title           = 'White'
        Breadcrumb      = 'DarkGray'
        ItemDefault     = ''
        ItemSelected    = 'Yellow'
        ItemHotkey      = 'DarkGray'
        ItemDescription = 'DarkGray'
        StatusLabel     = 'DarkGray'
        StatusValue     = 'Cyan'
        FooterText      = 'DarkGray'
    }

    if ($null -eq $Theme -or $Theme.Count -eq 0) {
        return $defaults
    }

    $validColors = [System.Enum]::GetNames([System.ConsoleColor])

    foreach ($key in $Theme.Keys) {
        if (-not $defaults.ContainsKey($key)) {
            $validKeyList = ($defaults.Keys | Sort-Object) -join ', '
            throw "Theme: '$key' is not a recognised theme key. Valid keys: $validKeyList"
        }
        $val = [string]$Theme[$key]
        # Empty string is allowed for ItemDefault (means terminal default foreground).
        if (-not [string]::IsNullOrEmpty($val) -and $validColors -notcontains $val) {
            throw "Theme: '$key' value '$val' is not a valid ConsoleColor name. Use a ConsoleColor name (e.g. 'Cyan', 'DarkGray') or an empty string for terminal default."
        }
    }

    # Merge: caller keys override defaults, all others stay as Default values
    $resolved = $defaults.Clone()
    foreach ($key in $Theme.Keys) {
        $resolved[$key] = $Theme[$key]
    }

    return $resolved
}
