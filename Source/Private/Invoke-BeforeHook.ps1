function Invoke-BeforeHook {
    <#
    .SYNOPSIS
        Executes a list of validated before hook functions in order.
    .DESCRIPTION
        For each hook in the list: verifies the function exists via Get-Command,
        clears the console so any inline prompts appear cleanly, then invokes
        the function with splatted params using the & call operator.

        If any hook returns $false, execution stops and this function returns $false.
        If any hook throws, the exception propagates to the caller.
        If all hooks pass (return anything other than $false), returns $true.

        Never uses Invoke-Expression. Always uses & call operator.
    .PARAMETER Hooks
        Array of normalized hook definition hashtables produced by Assert-BeforeHooks.
        Each entry must have:
            Hook   (string)     -- PowerShell function name (validated at parse time)
            Params (hashtable)  -- Splatted params (validated as scalars at parse time)
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [array]$Hooks
    )

    foreach ($hookDef in $Hooks) {
        $hookName = [string]$hookDef.Hook

        # Defense-in-depth: reject bad hook names even if they somehow bypassed parse-time validation.
        if ($hookName -match '[/\\]') {
            throw "Before hook '$hookName' must not contain path separators. Specify a function name only, not a script path."
        }
        if ($hookName -match '\.\w+$') {
            throw "Before hook '$hookName' must not have a file extension. Specify a function name only, not a script path."
        }

        # Whitelist via Get-Command before calling -- same guard used in Invoke-MenuAction.
        # Function-type only: anonymous scriptblocks and aliases are not supported.
        $cmd = Get-Command -Name $hookName -CommandType Function -ErrorAction SilentlyContinue
        if ($null -eq $cmd) {
            throw "Before hook function '$hookName' was not found. Ensure it is loaded in the current session before starting the menu."
        }

        # Build splatting hashtable. Convert YAML string booleans to native PS booleans
        # so SwitchParameter binding succeeds (same conversion used in Invoke-MenuAction).
        $splatParams = @{}
        if ($null -ne $hookDef.Params -and $hookDef.Params.Count -gt 0) {
            foreach ($key in $hookDef.Params.Keys) {
                $val = $hookDef.Params[$key]
                if ($val -is [string] -and $val -eq 'true') { $val = $true }
                elseif ($val -is [string] -and $val -eq 'false') { $val = $false }
                $splatParams[[string]$key] = $val
            }
        }

        # Clear before each hook so inline prompts (credentials, confirmations, input)
        # appear on a clean screen rather than over the rendered menu frame.
        # Some CI hosts do not provide a valid interactive console handle.
        try {
            [Console]::Clear()
        }
        catch {
            # Non-interactive host (for example GitHub Actions) -- continue without clearing.
        }

        $hookResult = & $cmd @splatParams

        # The hook contract requires an explicit $true or $false return value.
        # $false means "block execution" -- abort silently, do not show an error.
        if ($hookResult -eq $false) {
            return $false
        }
    }

    return $true
}
