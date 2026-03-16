function Read-MenuFile {
    <#
    .SYNOPSIS
        Parses and validates a YAML menu file into a normalized menu tree.
    .DESCRIPTION
        Loads the root menu.yaml, resolves all 'import' references, validates every node
        against the canonical schema, and infers node types. Returns a PSCustomObject tree
        ready for use by Show-MenuFrame.
    .PARAMETER Path
        Absolute or relative path to the root menu.yaml file.
    .PARAMETER VarsPath
        Optional path to a vars.yaml file. Must have a top-level 'vars' map. Any
        {{key}} token in the YAML is replaced with the matching value before parsing.
        Applied to root content and to imported submenu files. If omitted and no
        Context is supplied, no substitution occurs.
    .PARAMETER Context
        Optional hashtable of runtime values. Merged over VarsPath values; Context
        wins on any key conflict.
    .OUTPUTS
        PSCustomObject with Title and Items (array of validated node PSCustomObjects)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [string]$VarsPath,

        [Parameter()]
        [hashtable]$Context
    )

    # Resolve to absolute path for consistent root-jailing downstream
    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        throw "Menu file not found: $resolvedPath"
    }

    $rootDir = [System.IO.Path]::GetDirectoryName($resolvedPath)
    $content = Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8

    # -- Build token substitution dictionary ------------------------------------
    # Merge vars.yaml values first, then Context on top (Context wins on conflict).
    # Unknown tokens are left as-is. Applied to root content before parsing; the
    # same token dict is passed down into Resolve-MenuItems for imported files.
    $tokens = @{}
    if (-not [string]::IsNullOrWhiteSpace($VarsPath)) {
        if (-not (Test-Path -LiteralPath $VarsPath)) {
            throw "Vars file not found: $VarsPath"
        }
        $varsContent = Get-Content -LiteralPath $VarsPath -Raw -Encoding UTF8
        $varsRaw = ConvertFrom-YamlText -Content $varsContent
        if (-not ($varsRaw -is [hashtable]) -or -not $varsRaw.ContainsKey('vars')) {
            throw "Vars file '$VarsPath' must have a top-level 'vars' key."
        }
        foreach ($k in $varsRaw['vars'].Keys) {
            $tokens[[string]$k] = [string]$varsRaw['vars'][$k]
        }
    }
    if ($null -ne $Context) {
        foreach ($k in $Context.Keys) {
            $tokens[[string]$k] = [string]$Context[$k]
        }
    }
    if ($tokens.Count -gt 0) {
        foreach ($k in $tokens.Keys) {
            $content = $content.Replace("{{$k}}", [string]$tokens[$k])
        }
    }

    $raw = ConvertFrom-YamlText -Content $content

    # Build a label->line map from the (post-substitution) YAML text for error reporting
    $lineMap = Build-LabelLineMap -Content $content

    if (-not ($raw -is [hashtable]) -or -not $raw.ContainsKey('menu')) {
        throw "Root menu file '$resolvedPath' must have a top-level 'menu' key."
    }

    $menuNode = $raw['menu']

    if (-not ($menuNode -is [hashtable]) -or -not $menuNode.ContainsKey('items')) {
        throw "The 'menu' key in '$resolvedPath' must contain an 'items' array."
    }

    [PSCustomObject]@{
        Title = if ($menuNode.ContainsKey('title')) { [string]$menuNode['title'] } else { 'Menu' }
        Items = Resolve-MenuItems -Items $menuNode['items'] -RootDir $rootDir -LineMap $lineMap -Tokens $tokens
    }
}

# -- Internal helpers ----------------------------------------------------------

function Build-LabelLineMap {
    <#
    .SYNOPSIS
        Scans raw YAML text and returns a hashtable of { labelText = lineNumber }.
        Used to provide line numbers in validation error messages.
        If the same label appears multiple times the first occurrence wins.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )

    $map = @{}
    $lines = $Content -split '\r?\n'
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*-?\s*label:\s*["'']?(.+?)["'']?\s*$') {
            $lbl = $Matches[1].Trim()
            if (-not $map.ContainsKey($lbl)) {
                $map[$lbl] = $i + 1   # 1-based
            }
        }
    }
    return $map
}

function ConvertFrom-YamlText {
    <#
    .SYNOPSIS
        Deserializes a YAML string to nested PowerShell hashtables and arrays using YamlDotNet.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )

    # Verify YamlDotNet is loaded before attempting to use it
    try {
        $null = [YamlDotNet.Serialization.DeserializerBuilder]
    }
    catch {
        throw "YamlDotNet is not available. Ensure YamlDotNet.dll exists in the module's lib/ folder and the module was imported correctly."
    }

    $strReader = [System.IO.StringReader]::new($Content)
    $deserializer = [YamlDotNet.Serialization.DeserializerBuilder]::new().Build()
    $rawObject = $deserializer.Deserialize($strReader)

    return Convert-YamlNode -Node $rawObject
}

function Convert-YamlNode {
    <#
    .SYNOPSIS
        Recursively converts YamlDotNet output types to native PS hashtables and arrays.
    #>
    [CmdletBinding()]
    param($Node)

    if ($null -eq $Node) { return $null }

    # YamlDotNet returns Dictionary<object,object> for YAML mappings
    if ($Node -is [System.Collections.Generic.Dictionary[object, object]]) {
        $ht = @{}
        foreach ($key in $Node.Keys) {
            $ht[[string]$key] = Convert-YamlNode -Node $Node[$key]
        }
        return $ht
    }

    # YamlDotNet returns List<object> for YAML sequences
    if ($Node -is [System.Collections.Generic.List[object]]) {
        return @($Node | ForEach-Object { Convert-YamlNode -Node $_ })
    }

    return $Node
}

function Resolve-MenuItems {
    <#
    .SYNOPSIS
        Processes an items array, expanding 'import' references and validating each node.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Items,

        [Parameter(Mandatory)]
        [string]$RootDir,

        [Parameter()]
        [hashtable]$LineMap = @{},

        [Parameter()]
        [hashtable]$Tokens = @{}
    )

    $result = @()

    foreach ($item in $Items) {
        if (-not ($item -is [hashtable])) {
            throw "Each menu item must be a YAML mapping. Got: $($item.GetType().Name)"
        }

        if (-not $item.ContainsKey('label')) {
            throw "Every menu item must have a 'label' key."
        }

        $label = [string]$item['label']

        # -- Expand 'import' node into an inline BRANCH ------------------------
        if ($item.ContainsKey('import')) {
            if ($item.ContainsKey('children')) {
                throw "Item '$label': cannot have both 'import' and 'children' - pick one."
            }
            if ($item.ContainsKey('call')) {
                throw "Item '$label': cannot have both 'import' and 'call' - a node is either a branch or a leaf."
            }

            $importRelPath = [string]$item['import']

            # Enforce relative paths only — absolute paths are forbidden
            if ([System.IO.Path]::IsPathRooted($importRelPath)) {
                throw "Item '$label': 'import' path must be relative, not absolute: $importRelPath"
            }

            # Root-jail: resolve relative to RootDir and verify it stays inside
            $fullImportPath = [System.IO.Path]::GetFullPath(
                [System.IO.Path]::Combine($RootDir, $importRelPath)
            )
            if (-not $fullImportPath.StartsWith($RootDir, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Item '$label': 'import' path escapes the root directory: $importRelPath"
            }
            if (-not (Test-Path -LiteralPath $fullImportPath)) {
                throw "Item '$label': imported file not found: $fullImportPath"
            }

            $importedContent = Get-Content -LiteralPath $fullImportPath -Raw -Encoding UTF8
            # Apply the same token substitution pass to imported file content
            if ($Tokens.Count -gt 0) {
                foreach ($tk in $Tokens.Keys) {
                    $importedContent = $importedContent.Replace("{{$tk}}", [string]$Tokens[$tk])
                }
            }
            $importedRaw = ConvertFrom-YamlText -Content $importedContent

            if (-not ($importedRaw -is [hashtable]) -or -not $importedRaw.ContainsKey('items')) {
                throw "Imported file '$fullImportPath' must have a top-level 'items' key."
            }

            # Build a synthetic BRANCH hashtable with the imported children
            $syntheticBranch = @{
                label    = $label
                children = Resolve-MenuItems -Items $importedRaw['items'] -RootDir $RootDir -LineMap $LineMap -Tokens $Tokens
            }
            if ($item.ContainsKey('description')) { $syntheticBranch['description'] = $item['description'] }
            if ($item.ContainsKey('hotkey')) { $syntheticBranch['hotkey'] = $item['hotkey'] }
            if ($item.ContainsKey('before')) { $syntheticBranch['before'] = $item['before'] }

            $result += Assert-MenuItem -Item $syntheticBranch -RootDir $RootDir -LineMap $LineMap -Tokens $Tokens
        }
        else {
            $result += Assert-MenuItem -Item $item -RootDir $RootDir -LineMap $LineMap -Tokens $Tokens
        }
    }

    return $result
}

function Assert-MenuItem {
    <#
    .SYNOPSIS
        Validates a single menu item hashtable and returns a typed PSCustomObject node.
    .DESCRIPTION
        Applies the canonical node inference order:
          1. exit?              → EXIT node
          2. children?          → BRANCH node
          3. call *.ps1 / path? → SCRIPT node
          4. call (plain name)? → FUNCTION node
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Item,

        [Parameter(Mandatory)]
        [string]$RootDir,

        [Parameter()]
        [hashtable]$LineMap = @{},

        [Parameter()]
        [hashtable]$Tokens = @{}
    )

    $label = [string]$Item['label']
    $lineHint = if ($LineMap.ContainsKey($label)) { " (line $($LineMap[$label]))" } else { '' }

    # -- Common optional fields -------------------------------------------------
    $description = if ($Item.ContainsKey('description')) { [string]$Item['description'] } else { $null }

    $hotkey = $null
    if ($Item.ContainsKey('hotkey')) {
        $hotkey = [string]$Item['hotkey']
        if ($hotkey.Length -ne 1) {
            throw "Item '$label'${lineHint}: hotkey must be a single character. Got: '$hotkey'"
        }
    }

    # -- Optional 'before' hook(s) -----------------------------------------------
    $before = @()
    if ($Item.ContainsKey('before')) {
        $before = Assert-BeforeHooks -Value $Item['before'] -Label $label -LineHint $lineHint
    }

    # -- 1. EXIT ----------------------------------------------------------------
    if ($Item.ContainsKey('exit') -and $Item['exit'] -eq $true) {
        return [PSCustomObject]@{
            NodeType    = 'EXIT'
            Label       = $label
            Description = $description
            Hotkey      = $hotkey
            Before      = $before
        }
    }

    # -- 2. BRANCH --------------------------------------------------------------
    if ($Item.ContainsKey('children')) {
        if ($Item.ContainsKey('call')) {
            throw "Item '$label'${lineHint}: cannot have both 'children' and 'call'."
        }
        $children = $Item['children']
        if ($null -eq $children -or $children.Count -eq 0) {
            throw "Item '$label'${lineHint}: 'children' array must not be empty."
        }
        # Recursively resolve children so every descendant gets a proper NodeType
        $resolvedChildren = Resolve-MenuItems -Items $children -RootDir $RootDir -LineMap $LineMap -Tokens $Tokens
        return [PSCustomObject]@{
            NodeType    = 'BRANCH'
            Label       = $label
            Description = $description
            Hotkey      = $hotkey
            Children    = $resolvedChildren
            Before      = $before
        }
    }

    # -- 3 & 4. SCRIPT or FUNCTION — requires 'call' ---------------------------
    if (-not $Item.ContainsKey('call')) {
        throw "Item '$label'${lineHint}: unrecognized node - must have 'exit', 'children', 'import', or 'call'."
    }

    $call = [string]$Item['call']
    if ([string]::IsNullOrWhiteSpace($call)) {
        throw "Item '$label'${lineHint}: 'call' value must not be empty."
    }

    # -- Reject pipeline/multi-statement expressions ----------------------------
    if ($call -match '[|;&>]') {
        throw (
            "Item '$label'${lineHint}: 'call' value contains a pipeline or shell operator ('|', ';', '&', '>'). " +
            "Inline pipelines and compound statements cannot be executed safely. " +
            "Move the logic into a .ps1 script file and reference that path instead. " +
            "Example:  call: `"./scripts/My-Script.ps1`""
        )
    }

    # Validate params: values must be scalars only (no nested objects)
    $params = $null
    if ($Item.ContainsKey('params')) {
        $rawParams = $Item['params']
        if (-not ($rawParams -is [hashtable])) {
            throw "Item '$label'${lineHint}: 'params' must be a map of key/value pairs."
        }
        foreach ($k in $rawParams.Keys) {
            $v = $rawParams[$k]
            if ($v -is [hashtable] -or $v -is [array]) {
                throw "Item '$label'${lineHint}: param '$k' must be a string, bool, or number - nested objects are not allowed."
            }
        }
        $params = $rawParams
    }

    $confirm = $Item.ContainsKey('confirm') -and $Item['confirm'] -eq $true

    # -- 3. SCRIPT — ends in .ps1 or contains path separators -----------------
    if ($call -match '\.ps1$' -or $call -match '[/\\]') {
        return [PSCustomObject]@{
            NodeType    = 'SCRIPT'
            Label       = $label
            Description = $description
            Hotkey      = $hotkey
            Call        = $call
            Params      = $params
            Confirm     = $confirm
            Before      = $before
        }
    }

    # -- 4. FUNCTION — plain name, no extension, no path separators ------------
    return [PSCustomObject]@{
        NodeType    = 'FUNCTION'
        Label       = $label
        Description = $description
        Hotkey      = $hotkey
        Call        = $call
        Params      = $params
        Confirm     = $confirm
        Before      = $before
    }
}

# -- Before hook helpers -------------------------------------------------------

function Assert-BeforeHooks {
    <#
    .SYNOPSIS
        Normalizes and validates the 'before' value from a menu node.
        Returns an array of hook definition hashtables, each with 'Hook' (string)
        and 'Params' (hashtable). Supports string shorthand, single mapping, or
        an array of mappings.
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory)]
        $Value,

        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter()]
        [string]$LineHint = ''
    )

    if ($Value -is [string]) {
        # Shorthand: before: "FunctionName"
        Assert-HookName -Name $Value -Label $Label -LineHint $LineHint
        return @(@{ Hook = $Value; Params = @{} })
    }

    if ($Value -is [hashtable]) {
        # Single mapping: before: { hook: "...", params: {} }
        return @(Assert-HookObject -HookHt $Value -Label $Label -LineHint $LineHint)
    }

    if ($Value -is [array]) {
        # Multiple hooks: before: [{ hook: "..." }, ...]
        $result = [System.Collections.Generic.List[object]]::new()
        foreach ($entry in $Value) {
            if (-not ($entry -is [hashtable])) {
                throw "Item '$Label'${LineHint}: each entry in a 'before' array must be a mapping with a 'hook' key."
            }
            $result.Add((Assert-HookObject -HookHt $entry -Label $Label -LineHint $LineHint))
        }
        return $result.ToArray()
    }

    throw "Item '$Label'${LineHint}: 'before' must be a function name string, a hook mapping, or an array of hook mappings."
}

function Assert-HookName {
    <#
    .SYNOPSIS
        Validates that a hook name is a safe PowerShell function name.
        Rejects names with path separators, file extensions, or shell operators.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter()]
        [string]$LineHint = ''
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw "Item '$Label'${LineHint}: hook name must not be empty."
    }
    if ($Name -match '[|;&>]') {
        throw "Item '$Label'${LineHint}: hook name '$Name' contains an invalid character ('|', ';', '&', '>'). Use a plain function name."
    }
    if ($Name -match '[/\\]') {
        throw "Item '$Label'${LineHint}: hook name '$Name' must not contain path separators. Specify a function name only, not a script path."
    }
    if ($Name -match '\.\w+$') {
        throw "Item '$Label'${LineHint}: hook name '$Name' must not have a file extension. Specify a function name only, not a script path."
    }
}

function Assert-HookObject {
    <#
    .SYNOPSIS
        Validates and normalizes a single hook mapping (must have 'hook' key;
        'params' is optional). Returns @{ Hook = string; Params = hashtable }.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$HookHt,

        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter()]
        [string]$LineHint = ''
    )

    if (-not $HookHt.ContainsKey('hook')) {
        throw "Item '$Label'${LineHint}: a 'before' hook mapping must have a 'hook' key specifying the function name."
    }

    $hookName = [string]$HookHt['hook']
    Assert-HookName -Name $hookName -Label $Label -LineHint $LineHint

    $params = @{}
    if ($HookHt.ContainsKey('params')) {
        $rawParams = $HookHt['params']
        if (-not ($rawParams -is [hashtable])) {
            throw "Item '$Label'${LineHint}: hook '$hookName' params must be a mapping of key/value pairs."
        }
        foreach ($k in $rawParams.Keys) {
            $v = $rawParams[$k]
            if ($v -is [hashtable] -or $v -is [array]) {
                throw "Item '$Label'${LineHint}: hook '$hookName' param '$k' must be a string, bool, or number - nested objects are not allowed."
            }
        }
        $params = $rawParams
    }

    return @{ Hook = $hookName; Params = $params }
}

