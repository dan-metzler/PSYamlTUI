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

$steps = @(
    'Validate configuration and pre-flight checks'
    'Run pre-deployment test suite'
    'Stage deployment to 10% of nodes'
    'Monitor error rate for 5 minutes'
    'Roll out to remaining 90% of nodes'
    'Run post-deployment smoke tests'
    'Confirm and close deployment ticket'
)

Write-Host ''
Write-Host ('  Deployment Plan - {0}' -f $AppName) -ForegroundColor Cyan
Write-Host ('  {0}' -f ('-' * 50)) -ForegroundColor DarkCyan
Write-Host '  App         : ' -ForegroundColor DarkGray -NoNewline
Write-Host $AppName -ForegroundColor White
Write-Host '  Environment : ' -ForegroundColor DarkGray -NoNewline
Write-Host $Environment -ForegroundColor Yellow
Write-Host '  Region      : ' -ForegroundColor DarkGray -NoNewline
Write-Host $Region -ForegroundColor Yellow
Write-Host '  Requested By: ' -ForegroundColor DarkGray -NoNewline
Write-Host $RequestedBy -ForegroundColor White
Write-Host ''
Write-Host '  Rollout Steps' -ForegroundColor DarkCyan
$index = 1
foreach ($step in $steps) {
    Write-Host ('  {0,2}. {1}' -f $index, $step) -ForegroundColor Green
    $index++
}
Write-Host ('  {0}' -f ('-' * 50)) -ForegroundColor DarkCyan
Write-Host ("  Generated at: $(Get-Date -Format 'HH:mm:ss')") -ForegroundColor DarkGray
Write-Host ''
