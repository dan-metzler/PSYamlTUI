Write-Host ''
Write-Host '  Active TCP Connections' -ForegroundColor Cyan
Write-Host ('  {0}' -f ('-' * 62)) -ForegroundColor DarkCyan
Write-Host ('{0,-24} {1,-22} {2}' -f '  Local Endpoint', 'Remote Endpoint', 'State') -ForegroundColor DarkCyan
Write-Host ('  {0}' -f ('-' * 62)) -ForegroundColor DarkCyan

$conns = @()
try {
    $conns = @(Get-NetTCPConnection -State Established -ErrorAction Stop |
        Select-Object -First 12 -Property LocalAddress, LocalPort, RemoteAddress, RemotePort, State)
}
catch {
    $conns = @()
}

if ($conns.Count -eq 0) {
    Write-Host '  Could not read TCP state table -- showing example output.' -ForegroundColor DarkGray
    Write-Host ''
    $conns = @(
        [PSCustomObject]@{ LocalAddress = '127.0.0.1'; LocalPort = 5040; RemoteAddress = '127.0.0.1'; RemotePort = 49152; State = 'Established' }
        [PSCustomObject]@{ LocalAddress = '192.168.1.55'; LocalPort = 60201; RemoteAddress = '142.250.80.46'; RemotePort = 443; State = 'Established' }
        [PSCustomObject]@{ LocalAddress = '192.168.1.55'; LocalPort = 60202; RemoteAddress = '140.82.121.4'; RemotePort = 443; State = 'Established' }
        [PSCustomObject]@{ LocalAddress = '192.168.1.55'; LocalPort = 55100; RemoteAddress = '104.16.123.96'; RemotePort = 443; State = 'Established' }
        [PSCustomObject]@{ LocalAddress = '192.168.1.55'; LocalPort = 49320; RemoteAddress = '13.107.42.16'; RemotePort = 443; State = 'Established' }
    )
}

foreach ($c in $conns) {
    $local = ('{0}:{1}' -f $c.LocalAddress, $c.LocalPort)
    $remote = ('{0}:{1}' -f $c.RemoteAddress, $c.RemotePort)
    Write-Host ('  {0,-24}' -f $local) -ForegroundColor White -NoNewline
    Write-Host ('{0,-22}' -f $remote) -ForegroundColor Cyan -NoNewline
    Write-Host $c.State -ForegroundColor Green
}

Write-Host ('  {0}' -f ('-' * 62)) -ForegroundColor DarkCyan
Write-Host ("  Checked at: $(Get-Date -Format 'HH:mm:ss')") -ForegroundColor DarkGray
Write-Host ''
