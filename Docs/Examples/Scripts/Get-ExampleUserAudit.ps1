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

function Get-ExampleUserAudit {
    [CmdletBinding()]
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
    Write-Output ([PSCustomObject]@{
        Environment       = $Environment
        Region            = $Region
        IncludeDisabled   = $IncludeDisabled
        RequestedBy       = $RequestedBy
        EnabledUsers      = 128
        DisabledUsers     = if ($IncludeDisabled) { 7 } else { 0 }
        GeneratedAt       = (Get-Date)
    })
}

Get-ExampleUserAudit -Environment $Environment -Region $Region -IncludeDisabled $IncludeDisabled -RequestedBy $RequestedBy
