param(
    [Parameter()]
    [string]$Environment = 'dev',

    [Parameter()]
    [string]$Region = 'us-east-1'
)

Write-Host 'System summary generated.' -ForegroundColor Cyan
$result = [ordered]@{
    ComputerName = $env:COMPUTERNAME
    Environment  = $Environment
    Region       = $Region
    Timestamp    = (Get-Date)
    PSVersion    = $PSVersionTable.PSVersion.ToString()
}

foreach ($key in $result.Keys) {
    Write-Output ('{0,-12}: {1}' -f $key, $result[$key])
}
