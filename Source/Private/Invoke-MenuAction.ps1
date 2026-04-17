function Invoke-MenuAction {
    <#
    .SYNOPSIS
        Safely executes a SCRIPT or FUNCTION node from the menu tree.
    .DESCRIPTION
        For SCRIPT nodes: canonicalizes the path, root-jails it to the menu's root
        directory, verifies the file exists, then executes with & operator.

        For FUNCTION nodes: validates the function exists via Get-Command whitelist,
        then executes with & operator.

        Never uses Invoke-Expression. All params are passed via splatting.
    .PARAMETER Node
        A validated PSCustomObject node with NodeType of 'SCRIPT' or 'FUNCTION'.
    .PARAMETER RootDir
        The root directory of the menu file. All script paths are resolved relative
        to this directory and must remain inside it.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Node,

        [Parameter(Mandatory)]
        [string]$RootDir
    )

    # Build splatting hashtable from node params (already validated as scalars).
    # YamlDotNet returns unquoted YAML booleans as strings; convert them to native
    # PS booleans so SwitchParameter binding succeeds.
    $splatParams = @{}
    if ($null -ne $Node.Params) {
        foreach ($key in $Node.Params.Keys) {
            $val = $Node.Params[$key]
            if ($val -is [string] -and $val -eq 'true') { $val = $true }
            elseif ($val -is [string] -and $val -eq 'false') { $val = $false }
            $splatParams[[string]$key] = $val
        }
    }

    if ($Node.NodeType -eq 'SCRIPT') {
        # -- Canonicalize and root-jail the script path -------------------------
        $scriptPath = [System.IO.Path]::GetFullPath(
            [System.IO.Path]::Combine($RootDir, $Node.Call)
        )

        # Reject any path that escapes the root directory
        if (-not $scriptPath.StartsWith($RootDir, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Security: script path '$($Node.Call)' resolves outside the root directory."
        }

        if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
            throw "Script not found: $scriptPath"
        }

        & $scriptPath @splatParams | Out-Default

    }
    elseif ($Node.NodeType -eq 'FUNCTION') {
        # -- Whitelist via Get-Command before calling ---------------------------
        $cmd = Get-Command -Name $Node.Call -CommandType Function, Cmdlet -ErrorAction SilentlyContinue

        if ($null -eq $cmd) {
            throw "Function '$($Node.Call)' was not found. Ensure it is loaded in the current session before starting the menu."
        }

        & $cmd @splatParams | Out-Default

    }
    else {
        throw "Invoke-MenuAction: unexpected NodeType '$($Node.NodeType)'. Expected SCRIPT or FUNCTION."
    }
}

