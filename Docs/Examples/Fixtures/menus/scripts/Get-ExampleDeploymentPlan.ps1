param(
    [Parameter(Mandatory)]
    [string]$AppName,

    [Parameter(Mandatory)]
    [string]$Environment,

    [Parameter(Mandatory)]
    [string]$Region,

    [Parameter(Mandatory)]
    [string]$RequestedBy
)

Write-Host "Building deployment plan for $AppName in $Environment ($Region)." -ForegroundColor Green
$result = [ordered]@{
    AppName     = $AppName
    Environment = $Environment
    Region      = $Region
    RequestedBy = $RequestedBy
    PlanSummary = 'Validate config, run tests, perform staged rollout'
    GeneratedAt = (Get-Date)
}

foreach ($key in $result.Keys) {
    Write-Output ('{0,-12}: {1}' -f $key, $result[$key])
}
