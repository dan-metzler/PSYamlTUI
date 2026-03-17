param(
    [Parameter(Mandatory)]
    [string]$ServiceName,

    [Parameter(Mandatory)]
    [string]$Environment
)

$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($null -eq $service) {
    Write-Host ''
    Write-Host ("  Service '{0}' was not found." -f $ServiceName) -ForegroundColor Red
    Write-Host ''
    return
}

$statusColor = switch ($service.Status.ToString()) {
    'Running' { 'Green' }
    'Stopped' { 'Red' }
    'Paused' { 'Yellow' }
    'StartPending' { 'Cyan' }
    'StopPending' { 'Yellow' }
    default { 'Gray' }
}

Write-Host ''
Write-Host ('  {0}' -f $service.DisplayName) -ForegroundColor Cyan
Write-Host ('  {0}' -f ('-' * 38)) -ForegroundColor DarkCyan
Write-Host '  Environment  : ' -ForegroundColor DarkGray -NoNewline
Write-Host $Environment -ForegroundColor Yellow
Write-Host '  Service Name : ' -ForegroundColor DarkGray -NoNewline
Write-Host $service.Name -ForegroundColor White
Write-Host '  Status       : ' -ForegroundColor DarkGray -NoNewline
Write-Host $service.Status -ForegroundColor $statusColor
Write-Host '  Start Type   : ' -ForegroundColor DarkGray -NoNewline
Write-Host $service.StartType -ForegroundColor White
Write-Host ('  {0}' -f ('-' * 38)) -ForegroundColor DarkCyan
Write-Host ''
