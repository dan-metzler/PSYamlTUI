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
    [CmdletBinding(DefaultParameterSetName = 'ThemeHashtable')]
    [OutputType([hashtable])]
    param(
        [Parameter(ParameterSetName = 'ThemeHashtable')]
        [hashtable]$Theme,

        [Parameter(ParameterSetName = 'ThemeFile')]
        [string]$ThemePath
    )

    $defaults = Get-DefaultColorTheme

    if ($PSCmdlet.ParameterSetName -eq 'ThemeFile') {
        $Theme = Read-ColorThemeFile -ThemePath $ThemePath
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

        if ($Theme[$key] -is [System.Collections.IDictionary] -or
            (($Theme[$key] -is [System.Collections.IEnumerable]) -and -not ($Theme[$key] -is [string]))) {
            throw "Theme: '$key' must be a scalar ConsoleColor name, not a nested object or array."
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

function Get-DefaultColorTheme {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    return @{
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
}

function Read-ColorThemeFile {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$ThemePath
    )

    $resolvedThemePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ThemePath)
    if (-not (Test-Path -LiteralPath $resolvedThemePath -PathType Leaf)) {
        throw "Theme file not found: $resolvedThemePath"
    }

    $extension = [System.IO.Path]::GetExtension($resolvedThemePath).ToLowerInvariant()
    $content = Get-Content -LiteralPath $resolvedThemePath -Raw -Encoding UTF8

    switch ($extension) {
        '.yaml' {
            try {
                $rawTheme = ConvertFrom-YamlText -Content $content
            }
            catch {
                throw "Theme file '$resolvedThemePath' could not be parsed as YAML: $($_.Exception.Message)"
            }
        }
        '.yml' {
            try {
                $rawTheme = ConvertFrom-YamlText -Content $content
            }
            catch {
                throw "Theme file '$resolvedThemePath' could not be parsed as YAML: $($_.Exception.Message)"
            }
        }
        '.json' {
            try {
                $rawTheme = ConvertTo-ThemeHashtable -InputObject (ConvertFrom-Json -InputObject $content -ErrorAction Stop)
            }
            catch {
                throw "Theme file '$resolvedThemePath' could not be parsed as JSON: $($_.Exception.Message)"
            }
        }
        default {
            throw "Theme file '$resolvedThemePath' must use .yaml, .yml, or .json extension."
        }
    }

    if (-not ($rawTheme -is [hashtable])) {
        throw "Theme file '$resolvedThemePath' must deserialize to a mapping of theme keys."
    }

    $themeData = $rawTheme
    if ($rawTheme.ContainsKey('theme')) {
        $themeData = $rawTheme['theme']
    }

    if (-not ($themeData -is [hashtable])) {
        throw "Theme file '$resolvedThemePath' must contain a top-level 'theme' mapping or a flat mapping of theme keys."
    }

    return $themeData
}

function ConvertTo-ThemeHashtable {
    [CmdletBinding()]
    param($InputObject)

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [hashtable]) {
        $copy = @{}
        foreach ($key in $InputObject.Keys) {
            $copy[[string]$key] = ConvertTo-ThemeHashtable -InputObject $InputObject[$key]
        }
        return $copy
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $copy = @{}
        foreach ($key in $InputObject.Keys) {
            $copy[[string]$key] = ConvertTo-ThemeHashtable -InputObject $InputObject[$key]
        }
        return $copy
    }

    if ($InputObject -is [pscustomobject]) {
        $copy = @{}
        foreach ($prop in $InputObject.PSObject.Properties) {
            $copy[[string]$prop.Name] = ConvertTo-ThemeHashtable -InputObject $prop.Value
        }
        return $copy
    }

    if (($InputObject -is [System.Collections.IEnumerable]) -and -not ($InputObject -is [string])) {
        return @($InputObject | ForEach-Object { ConvertTo-ThemeHashtable -InputObject $_ })
    }

    return $InputObject
}
