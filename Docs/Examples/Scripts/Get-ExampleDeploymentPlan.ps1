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

function Get-ExampleDeploymentPlan {
    [CmdletBinding()]
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
    Write-Output ([PSCustomObject]@{
        AppName      = $AppName
        Environment  = $Environment
        Region       = $Region
        RequestedBy  = $RequestedBy
        PlanSummary  = 'Validate config, run tests, perform staged rollout'
        GeneratedAt  = (Get-Date)
    })
}

Get-ExampleDeploymentPlan -AppName $AppName -Environment $Environment -Region $Region -RequestedBy $RequestedBy
