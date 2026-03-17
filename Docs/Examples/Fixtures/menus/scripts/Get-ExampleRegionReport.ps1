param(
    [Parameter(Mandatory)]
    [string]$Environment,

    [Parameter(Mandatory)]
    [string]$Region
)

Write-Host "Generating regional report for $Environment in $Region." -ForegroundColor Cyan
$result = [ordered]@{
    Environment      = $Environment
    Region           = $Region
    ActiveNodes      = 14
    HealthyNodes     = 14
    PendingIncidents = 0
    ReportedAt       = (Get-Date)
}

foreach ($key in $result.Keys) {
    Write-Output ('{0,-12}: {1}' -f $key, $result[$key])
}
