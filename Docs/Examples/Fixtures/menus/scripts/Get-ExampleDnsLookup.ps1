param(
    [Parameter()]
    [string]$Hostnames = 'google.com,github.com,cloudflare.com'
)

$hosts = $Hostnames -split ','

Write-Host ''
Write-Host '  DNS Resolution' -ForegroundColor Cyan
Write-Host ('  {0}' -f ('-' * 52)) -ForegroundColor DarkCyan
Write-Host ('{0,-26} {1}' -f '  Hostname', 'Resolved IP(s)') -ForegroundColor DarkCyan
Write-Host ('  {0}' -f ('-' * 52)) -ForegroundColor DarkCyan

foreach ($h in $hosts) {
    $h = $h.Trim()
    if ([string]::IsNullOrWhiteSpace($h)) { continue }

    try {
        $resolved = [System.Net.Dns]::GetHostAddresses($h) |
        ForEach-Object { $_.IPAddressToString } |
        Select-Object -First 3
        $ips = $resolved -join ',  '
        Write-Host ('  {0,-24}' -f $h) -ForegroundColor White -NoNewline
        Write-Host $ips -ForegroundColor Green
    }
    catch {
        Write-Host ('  {0,-24}' -f $h) -ForegroundColor White -NoNewline
        Write-Host 'Resolution failed' -ForegroundColor Red
    }
}

Write-Host ('  {0}' -f ('-' * 52)) -ForegroundColor DarkCyan
Write-Host ("  Checked at: $(Get-Date -Format 'HH:mm:ss')") -ForegroundColor DarkGray
Write-Host ''
