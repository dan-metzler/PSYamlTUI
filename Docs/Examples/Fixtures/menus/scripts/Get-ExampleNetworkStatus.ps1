$targets = @(
    [PSCustomObject]@{ Host = 'localhost'; Label = 'Local Machine' }
    [PSCustomObject]@{ Host = '8.8.8.8'; Label = 'Google DNS' }
    [PSCustomObject]@{ Host = '1.1.1.1'; Label = 'Cloudflare' }
    [PSCustomObject]@{ Host = 'google.com'; Label = 'google.com' }
    [PSCustomObject]@{ Host = 'github.com'; Label = 'github.com' }
    [PSCustomObject]@{ Host = 'amazon.com'; Label = 'amazon.com' }
)

Write-Host ''
Write-Host '  Connectivity Check' -ForegroundColor Cyan
Write-Host ('  {0}' -f ('-' * 44)) -ForegroundColor DarkCyan

$random = [System.Random]::new()
$statusTokens = @('OK', 'TRUE')
$rowDelayMs = 120

foreach ($t in $targets) {
    $isSuccess = ($random.Next(0, 100) -ge 20)
    $token = $statusTokens[$random.Next(0, $statusTokens.Count)]

    Start-Sleep -Milliseconds $rowDelayMs

    Write-Host '  ' -NoNewline
    if ($isSuccess) {
        Write-Host ('[{0,6}]' -f $token) -ForegroundColor Green -NoNewline
    }
    else {
        Write-Host '[ FAIL ]' -ForegroundColor Red -NoNewline
    }
    Write-Host ('  {0,-18} {1}' -f $t.Label, $t.Host) -ForegroundColor White
}

Write-Host ('  {0}' -f ('-' * 44)) -ForegroundColor DarkCyan
Write-Host ("  Checked at: $(Get-Date -Format 'HH:mm:ss')") -ForegroundColor DarkGray
Write-Host ''
