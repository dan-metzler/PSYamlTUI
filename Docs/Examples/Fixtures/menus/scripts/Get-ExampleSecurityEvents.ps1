Write-Host ''
Write-Host '  Recent Security Events' -ForegroundColor Cyan
Write-Host ('  {0}' -f ('-' * 56)) -ForegroundColor DarkCyan

try {
    $events = @(Get-EventLog -LogName Security -Newest 8 -ErrorAction Stop |
        Select-Object -Property TimeGenerated, EventID, EntryType, Message)

    Write-Host ('{0,-22} {1,-8} {2}' -f '  Time', 'EventID', 'Type') -ForegroundColor DarkCyan

    foreach ($ev in $events) {
        $typeColor = switch ($ev.EntryType.ToString()) {
            'SuccessAudit' { 'Green' }
            'FailureAudit' { 'Red' }
            default { 'Yellow' }
        }
        Write-Host ('  {0,-20}' -f $ev.TimeGenerated.ToString('MM-dd HH:mm:ss')) -ForegroundColor White -NoNewline
        Write-Host ('{0,-8}  ' -f $ev.EventID) -ForegroundColor Cyan -NoNewline
        Write-Host $ev.EntryType -ForegroundColor $typeColor
    }
}
catch {
    Write-Host '  Security log requires elevated privileges -- showing sample data.' -ForegroundColor DarkYellow
    Write-Host ''
    Write-Host ('{0,-22} {1,-8} {2}' -f '  Time', 'EventID', 'Type') -ForegroundColor DarkCyan

    $now = Get-Date
    $mockEvents = @(
        [PSCustomObject]@{ Time = $now.AddMinutes(-2).ToString('MM-dd HH:mm:ss'); ID = '4624'; Type = 'SuccessAudit' }
        [PSCustomObject]@{ Time = $now.AddMinutes(-5).ToString('MM-dd HH:mm:ss'); ID = '4672'; Type = 'SuccessAudit' }
        [PSCustomObject]@{ Time = $now.AddMinutes(-15).ToString('MM-dd HH:mm:ss'); ID = '4634'; Type = 'SuccessAudit' }
        [PSCustomObject]@{ Time = $now.AddMinutes(-42).ToString('MM-dd HH:mm:ss'); ID = '4625'; Type = 'FailureAudit' }
        [PSCustomObject]@{ Time = $now.AddHours(-1).ToString('MM-dd HH:mm:ss'); ID = '4648'; Type = 'SuccessAudit' }
        [PSCustomObject]@{ Time = $now.AddHours(-2).ToString('MM-dd HH:mm:ss'); ID = '4647'; Type = 'SuccessAudit' }
        [PSCustomObject]@{ Time = $now.AddHours(-3).ToString('MM-dd HH:mm:ss'); ID = '4625'; Type = 'FailureAudit' }
        [PSCustomObject]@{ Time = $now.AddHours(-4).ToString('MM-dd HH:mm:ss'); ID = '4624'; Type = 'SuccessAudit' }
    )

    foreach ($ev in $mockEvents) {
        $typeColor = if ($ev.Type -eq 'FailureAudit') { 'Red' } else { 'Green' }
        Write-Host ('  {0,-20}' -f $ev.Time) -ForegroundColor White -NoNewline
        Write-Host ('{0,-8}  ' -f $ev.ID) -ForegroundColor Cyan -NoNewline
        Write-Host $ev.Type -ForegroundColor $typeColor
    }
}

Write-Host ('  {0}' -f ('-' * 56)) -ForegroundColor DarkCyan
Write-Host ("  Checked at: $(Get-Date -Format 'HH:mm:ss')") -ForegroundColor DarkGray
Write-Host ''
