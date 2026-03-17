param(
    [Parameter()]
    [string]$Environment = 'dev',

    [Parameter()]
    [string]$Region = 'us-east-1'
)

function Get-ExampleSystemSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Environment,

        [Parameter(Mandatory)]
        [string]$Region
    )

    $output = [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        Environment  = $Environment
        Region       = $Region
        Timestamp    = (Get-Date)
        PSVersion    = $PSVersionTable.PSVersion.ToString()
    }

    Write-Host 'System summary generated.' -ForegroundColor Cyan
    return $output
}

Get-ExampleSystemSummary -Environment $Environment -Region $Region
