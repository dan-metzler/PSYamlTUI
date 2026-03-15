[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Target,

    [Parameter()]
    [ValidateRange(1, 10)]
    [int]$Count = 4
)

Write-Host ""
Write-Host "  === Ping: $Target ===" -ForegroundColor Cyan
Write-Host ""

$success = 0
$fail    = 0
$times   = @()

for ($i = 1; $i -le $Count; $i++) {
    $ping   = [System.Net.NetworkInformation.Ping]::new()
    $result = $ping.Send($Target, 2000)
    $ping.Dispose()

    if ($result.Status -eq 'Success') {
        $success++
        $times += $result.RoundtripTime
        Write-Host ("  [{0}/{1}] Reply from {2}  time={3}ms" -f $i, $Count, $result.Address, $result.RoundtripTime) -ForegroundColor Green
    }
    else {
        $fail++
        Write-Host ("  [{0}/{1}] Request timed out ({2})" -f $i, $Count, $result.Status) -ForegroundColor Red
    }

    if ($i -lt $Count) { Start-Sleep -Milliseconds 500 }
}

Write-Host ""
Write-Host ("  Sent: {0}  Received: {1}  Lost: {2}" -f $Count, $success, $fail) -ForegroundColor $(
    if ($fail -eq 0) { 'Green' } elseif ($success -eq 0) { 'Red' } else { 'Yellow' }
)
if ($times.Count -gt 0) {
    $avg = [Math]::Round(($times | Measure-Object -Average).Average, 1)
    $min = ($times | Measure-Object -Minimum).Minimum
    $max = ($times | Measure-Object -Maximum).Maximum
    Write-Host ("  RTT min/avg/max = {0}/{1}/{2} ms" -f $min, $avg, $max) -ForegroundColor DarkGray
}
Write-Host ""
