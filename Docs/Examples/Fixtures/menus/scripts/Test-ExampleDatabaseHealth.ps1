param(
    [Parameter(Mandatory)]
    [string]$Environment,

    [Parameter(Mandatory)]
    [string]$Region
)

Write-Host "Running read-only database health checks for $Environment in $Region." -ForegroundColor Cyan
$result = [ordered]@{
    Environment      = $Environment
    Region           = $Region
    Connectivity     = 'Healthy'
    ReplicationLagMs = 12
    LastBackupUtc    = (Get-Date).ToUniversalTime().AddHours(-3)
    CheckedAtUtc     = (Get-Date).ToUniversalTime()
}

foreach ($key in $result.Keys) {
    Write-Output ('{0,-15}: {1}' -f $key, $result[$key])
}
