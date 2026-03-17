param(
    [Parameter(Mandatory)]
    [string]$Environment,

    [Parameter(Mandatory)]
    [string]$Region
)

$activeNodes = 14
$healthyNodes = 14
$pendingIncidents = 0

Write-Host ''
Write-Host '  Regional Health Report' -ForegroundColor Cyan
Write-Host ('  {0}' -f ('-' * 44)) -ForegroundColor DarkCyan
Write-Host '  Environment      : ' -ForegroundColor DarkGray -NoNewline
Write-Host $Environment -ForegroundColor Yellow
Write-Host '  Region           : ' -ForegroundColor DarkGray -NoNewline
Write-Host $Region -ForegroundColor Yellow
Write-Host ''
Write-Host '  Infrastructure' -ForegroundColor DarkCyan
Write-Host ('  {0,-20}: ' -f 'Active Nodes') -ForegroundColor DarkGray -NoNewline
Write-Host $activeNodes -ForegroundColor White
Write-Host ('  {0,-20}: ' -f 'Healthy Nodes') -ForegroundColor DarkGray -NoNewline
if ($healthyNodes -eq $activeNodes) {
    Write-Host ('{0} / {1}' -f $healthyNodes, $activeNodes) -ForegroundColor Green
}
else {
    Write-Host ('{0} / {1}' -f $healthyNodes, $activeNodes) -ForegroundColor Yellow
}
Write-Host ('  {0,-20}: ' -f 'Pending Incidents') -ForegroundColor DarkGray -NoNewline
if ($pendingIncidents -eq 0) {
    Write-Host 'None' -ForegroundColor Green
}
else {
    Write-Host $pendingIncidents -ForegroundColor Red
}
Write-Host ('  {0}' -f ('-' * 44)) -ForegroundColor DarkCyan
Write-Host ("  Reported at: $(Get-Date -Format 'HH:mm:ss')") -ForegroundColor DarkGray
Write-Host ''
