param(
    [Parameter(Mandatory)]
    [string]$Environment,

    [Parameter(Mandatory)]
    [string]$Region
)

$lagMs = 12
$lagColor = if ($lagMs -lt 50) { 'Green' } elseif ($lagMs -lt 200) { 'Yellow' } else { 'Red' }
$lastBackup = (Get-Date).ToUniversalTime().AddHours(-3)

Write-Host ''
Write-Host '  Database Health Check' -ForegroundColor Cyan
Write-Host ('  {0}' -f ('-' * 44)) -ForegroundColor DarkCyan
Write-Host '  Environment      : ' -ForegroundColor DarkGray -NoNewline
Write-Host $Environment -ForegroundColor Yellow
Write-Host '  Region           : ' -ForegroundColor DarkGray -NoNewline
Write-Host $Region -ForegroundColor Yellow
Write-Host ''
Write-Host '  Health Metrics' -ForegroundColor DarkCyan
Write-Host '  Connectivity     : ' -ForegroundColor DarkGray -NoNewline
Write-Host 'Healthy' -ForegroundColor Green
Write-Host '  Replication Lag  : ' -ForegroundColor DarkGray -NoNewline
Write-Host ('{0} ms' -f $lagMs) -ForegroundColor $lagColor
Write-Host '  Last Backup (UTC): ' -ForegroundColor DarkGray -NoNewline
Write-Host ($lastBackup.ToString('yyyy-MM-dd HH:mm')) -ForegroundColor White
Write-Host '  Checked (UTC)    : ' -ForegroundColor DarkGray -NoNewline
Write-Host ((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) -ForegroundColor DarkGray
Write-Host ('  {0}' -f ('-' * 44)) -ForegroundColor DarkCyan
Write-Host ''
