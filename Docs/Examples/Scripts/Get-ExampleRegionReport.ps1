param(
    [Parameter(Mandatory)]
    [string]$Environment,

    [Parameter(Mandatory)]
    [string]$Region
)

function Get-ExampleRegionReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Environment,

        [Parameter(Mandatory)]
        [string]$Region
    )

    Write-Host "Generating regional report for $Environment in $Region." -ForegroundColor Cyan
    Write-Output ([PSCustomObject]@{
        Environment       = $Environment
        Region            = $Region
        ActiveNodes       = 14
        HealthyNodes      = 14
        PendingIncidents  = 0
        ReportedAt        = (Get-Date)
    })
}

Get-ExampleRegionReport -Environment $Environment -Region $Region
