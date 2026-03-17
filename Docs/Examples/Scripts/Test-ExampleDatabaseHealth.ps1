param(
    [Parameter(Mandatory)]
    [string]$Environment,

    [Parameter(Mandatory)]
    [string]$Region
)

function Test-ExampleDatabaseHealth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Environment,

        [Parameter(Mandatory)]
        [string]$Region
    )

    Write-Host "Running read-only database health checks for $Environment in $Region." -ForegroundColor Cyan
    Write-Output ([PSCustomObject]@{
        Environment        = $Environment
        Region             = $Region
        Connectivity       = 'Healthy'
        ReplicationLagMs   = 12
        LastBackupUtc      = (Get-Date).ToUniversalTime().AddHours(-3)
        CheckedAtUtc       = (Get-Date).ToUniversalTime()
    })
}

Test-ExampleDatabaseHealth -Environment $Environment -Region $Region
