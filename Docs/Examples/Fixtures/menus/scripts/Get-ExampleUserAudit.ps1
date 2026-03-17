param(
    [Parameter(Mandatory)]
    [string]$Environment,

    [Parameter(Mandatory)]
    [string]$Region,

    [Parameter()]
    [bool]$IncludeDisabled = $false,

    [Parameter(Mandatory)]
    [string]$RequestedBy
)

$enabledUsers = 128
$disabledUsers = if ($IncludeDisabled) { 7 } else { 0 }
$totalUsers = $enabledUsers + $disabledUsers

Write-Host ''
Write-Host '  User Audit Report' -ForegroundColor Cyan
Write-Host ('  {0}' -f ('-' * 44)) -ForegroundColor DarkCyan
Write-Host '  Environment     : ' -ForegroundColor DarkGray -NoNewline
Write-Host $Environment -ForegroundColor Yellow
Write-Host '  Region          : ' -ForegroundColor DarkGray -NoNewline
Write-Host $Region -ForegroundColor Yellow
Write-Host '  Requested By    : ' -ForegroundColor DarkGray -NoNewline
Write-Host $RequestedBy -ForegroundColor White
Write-Host ''
Write-Host '  Account Summary' -ForegroundColor DarkCyan
Write-Host ('  {0,-18}: ' -f 'Enabled Users') -ForegroundColor DarkGray -NoNewline
Write-Host $enabledUsers -ForegroundColor Green
if ($IncludeDisabled) {
    Write-Host ('  {0,-18}: ' -f 'Disabled Users') -ForegroundColor DarkGray -NoNewline
    Write-Host $disabledUsers -ForegroundColor Red
}
Write-Host ('  {0,-18}: ' -f 'Total Accounts') -ForegroundColor DarkGray -NoNewline
Write-Host $totalUsers -ForegroundColor White
Write-Host ''
Write-Host '  Include Disabled : ' -ForegroundColor DarkGray -NoNewline
if ($IncludeDisabled) {
    Write-Host 'Yes' -ForegroundColor Yellow
}
else {
    Write-Host 'No' -ForegroundColor Gray
}
Write-Host ('  {0}' -f ('-' * 44)) -ForegroundColor DarkCyan
Write-Host ("  Generated at: $(Get-Date -Format 'HH:mm:ss')") -ForegroundColor DarkGray
Write-Host ''
