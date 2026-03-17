$serviceNames = @(
    'Spooler'
    'W32Time'
    'Dnscache'
    'WinDefend'
    'BITS'
    'wuauserv'
    'EventLog'
    'Schedule'
    'LanmanServer'
    'Netlogon'
)

Write-Host ''
Write-Host '  Service Status Summary' -ForegroundColor Cyan
Write-Host ('  {0}' -f ('-' * 52)) -ForegroundColor DarkCyan
Write-Host ('{0,-24} {1,-14} {2}' -f '  Service', 'Status', 'Start Type') -ForegroundColor DarkCyan
Write-Host ('  {0}' -f ('-' * 52)) -ForegroundColor DarkCyan

foreach ($name in $serviceNames) {
    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
    if ($null -eq $svc) {
        Write-Host ('  {0,-22}' -f $name) -ForegroundColor DarkGray -NoNewline
        Write-Host '  Not found' -ForegroundColor DarkGray
        continue
    }

    $displayName = $svc.DisplayName
    if ($displayName.Length -gt 20) {
        $displayName = $displayName.Substring(0, 20)
    }

    $statusColor = switch ($svc.Status.ToString()) {
        'Running' { 'Green' }
        'Stopped' { 'Red' }
        default { 'Yellow' }
    }

    Write-Host ('  {0,-22}' -f $displayName) -ForegroundColor White -NoNewline
    Write-Host ('{0,-15}' -f $svc.Status) -ForegroundColor $statusColor -NoNewline
    Write-Host $svc.StartType -ForegroundColor DarkGray
}

Write-Host ('  {0}' -f ('-' * 52)) -ForegroundColor DarkCyan
Write-Host ("  Checked at: $(Get-Date -Format 'HH:mm:ss')") -ForegroundColor DarkGray
Write-Host ''
