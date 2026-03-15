[CmdletBinding()]
param()

Write-Host ""
Write-Host "  === System Information ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Hostname   : $($env:COMPUTERNAME)" -ForegroundColor White
Write-Host "  Username   : $($env:USERNAME)" -ForegroundColor White
Write-Host "  OS         : $([System.Environment]::OSVersion.VersionString)" -ForegroundColor White
Write-Host "  PS Version : $($PSVersionTable.PSVersion)" -ForegroundColor White
Write-Host "  Uptime     : $(
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($os) {
        $up = (Get-Date) - $os.LastBootUpTime
        '{0}d {1}h {2}m' -f [int]$up.TotalDays, $up.Hours, $up.Minutes
    } else { 'N/A' }
)" -ForegroundColor White
Write-Host ""
Write-Host "  === Disk Usage ===" -ForegroundColor Cyan
Write-Host ""
Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Used -ne $null -and $_.Free -ne $null) {
        $total = $_.Used + $_.Free
        $pct = if ($total -gt 0) { [int](($_.Used / $total) * 100) } else { 0 }
        $bar = ('#' * [int]($pct / 5)).PadRight(20)
        Write-Host ("  [{0}] {1,3}%  {2}" -f $bar, $pct, $_.Root) -ForegroundColor $(
            if ($pct -ge 85) { 'Red' } elseif ($pct -ge 65) { 'Yellow' } else { 'Green' }
        )
    }
}
Write-Host ""
