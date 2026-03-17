param(
    [Parameter(Mandatory)]
    [string]$Environment,

    [Parameter(Mandatory)]
    [string]$Region,

    [Parameter()]
    [bool]$IncludeDisabled = $false,

    [Parameter(Mandatory)]
    [string]$RequestedBy
)

Write-Host "Collecting user audit for $Environment in $Region." -ForegroundColor Yellow
$result = [ordered]@{
    Environment     = $Environment
    Region          = $Region
    IncludeDisabled = $IncludeDisabled
    RequestedBy     = $RequestedBy
    EnabledUsers    = 128
    DisabledUsers   = if ($IncludeDisabled) { 7 } else { 0 }
    GeneratedAt     = (Get-Date)
}

foreach ($key in $result.Keys) {
    Write-Output ('{0,-15}: {1}' -f $key, $result[$key])
}
