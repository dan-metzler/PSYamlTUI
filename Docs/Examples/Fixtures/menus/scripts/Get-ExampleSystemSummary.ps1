param(
    [Parameter()]
    [string]$Environment = 'dev',

    [Parameter()]
    [string]$Region = 'us-east-1'
)

$osVersion = [System.Environment]::OSVersion.VersionString
$cpuName = $env:PROCESSOR_IDENTIFIER
$cpuCores = $env:NUMBER_OF_PROCESSORS
$psVersion = $PSVersionTable.PSVersion.ToString()
$cpuDisplay = if ($cpuName.Length -gt 44) { $cpuName.Substring(0, 44) + '...' } else { $cpuName }

Write-Host ''
Write-Host '  System Summary' -ForegroundColor Cyan
Write-Host ('  {0}' -f ('-' * 48)) -ForegroundColor DarkCyan
Write-Host '  Machine   : ' -ForegroundColor DarkGray -NoNewline
Write-Host $env:COMPUTERNAME -ForegroundColor White
Write-Host '  OS        : ' -ForegroundColor DarkGray -NoNewline
Write-Host $osVersion -ForegroundColor White
Write-Host '  CPU       : ' -ForegroundColor DarkGray -NoNewline
Write-Host ('{0}  ({1} cores)' -f $cpuDisplay, $cpuCores) -ForegroundColor White
Write-Host '  PS Ver    : ' -ForegroundColor DarkGray -NoNewline
Write-Host $psVersion -ForegroundColor Cyan
Write-Host '  Env       : ' -ForegroundColor DarkGray -NoNewline
Write-Host $Environment -ForegroundColor Yellow
Write-Host '  Region    : ' -ForegroundColor DarkGray -NoNewline
Write-Host $Region -ForegroundColor Yellow
Write-Host '  Timestamp : ' -ForegroundColor DarkGray -NoNewline
Write-Host (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -ForegroundColor DarkGray
Write-Host ('  {0}' -f ('-' * 48)) -ForegroundColor DarkCyan
Write-Host ''
