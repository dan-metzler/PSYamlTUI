function Get-CharacterSet {
    <#
    .SYNOPSIS
        Returns the appropriate character set hashtable based on terminal capabilities.
    .DESCRIPTION
        Returns Unicode box-drawing characters for capable terminals, or ASCII fallback
        characters for terminals that cannot render Unicode. Characters are used by the
        rendering engine (Show-MenuFrame) throughout all three tiers.
    .PARAMETER TerminalProfile
        The terminal profile object returned by Get-TerminalProfile.
    .PARAMETER Style
        The border style to use when the terminal supports Unicode.
        Single (default), Double, Rounded, Heavy, or ASCII.
        ASCII is always used when the terminal does not support Unicode.
    .OUTPUTS
        Hashtable with keys: TopLeft, TopRight, BottomLeft, BottomRight, Horizontal,
        Vertical, LeftT, RightT, Selected, Bullet, Arrow
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$TerminalProfile,

        [Parameter()]
        [ValidateSet('Single', 'Double', 'Rounded', 'Heavy', 'ASCII')]
        [string]$Style = 'Single'
    )

    # ASCII fallback -- works on every terminal without exception
    $ascii = @{
        TopLeft     = '+'
        TopRight    = '+'
        BottomLeft  = '+'
        BottomRight = '+'
        Horizontal  = '-'
        Vertical    = '|'
        LeftT       = '+'
        RightT      = '+'
        Selected    = '>'
        Bullet      = '*'
        Arrow       = '->'
    }

    if (-not $TerminalProfile.UseUnicode -or $Style -eq 'ASCII') { return $ascii }

    # Unicode character sets -- Selected, Bullet, Arrow shared across all styles
    $sets = @{
        Single = @{
            TopLeft     = [string][char]0x250C  # +
            TopRight    = [string][char]0x2510  # +
            BottomLeft  = [string][char]0x2514  # +
            BottomRight = [string][char]0x2518  # +
            Horizontal  = [string][char]0x2500  # -
            Vertical    = [string][char]0x2502  # |
            LeftT       = [string][char]0x251C  # +-
            RightT      = [string][char]0x2524  # -+
        }
        Double = @{
            TopLeft     = [string][char]0x2554  # ++
            TopRight    = [string][char]0x2557  # ++
            BottomLeft  = [string][char]0x255A  # ++
            BottomRight = [string][char]0x255D  # ++
            Horizontal  = [string][char]0x2550  # =
            Vertical    = [string][char]0x2551  # ||
            LeftT       = [string][char]0x2560  # |=
            RightT      = [string][char]0x2563  # =|
        }
        Rounded = @{
            TopLeft     = [string][char]0x256D  # ,
            TopRight    = [string][char]0x256E  # .
            BottomLeft  = [string][char]0x2570  # '
            BottomRight = [string][char]0x256F  # '
            Horizontal  = [string][char]0x2500  # -
            Vertical    = [string][char]0x2502  # |
            LeftT       = [string][char]0x251C  # +-
            RightT      = [string][char]0x2524  # -+
        }
        Heavy = @{
            TopLeft     = [string][char]0x250F  # +
            TopRight    = [string][char]0x2513  # +
            BottomLeft  = [string][char]0x2517  # +
            BottomRight = [string][char]0x251B  # +
            Horizontal  = [string][char]0x2501  # -
            Vertical    = [string][char]0x2503  # |
            LeftT       = [string][char]0x2523  # +-
            RightT      = [string][char]0x252B  # -+
        }
    }

    $chosen = $sets[$Style]
    $chosen['Selected'] = [string][char]0x25BA  # filled triangle (CP437-safe)
    $chosen['Bullet']   = [string][char]0x00B7  # middle dot (CP437-safe)
    $chosen['Arrow']    = [string][char]0x00BB  # double angle (CP437-safe)
    return $chosen
}
