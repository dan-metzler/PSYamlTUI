param(
    [Parameter()]
    [ValidateRange(1, 50)]
    [int]$Top = 10
)

Write-Host ''
Write-Host ('  Top {0} Processes by Memory' -f $Top) -ForegroundColor Cyan
Write-Host ('  {0}' -f ('-' * 46)) -ForegroundColor DarkCyan
Write-Host ('{0,-30} {1,12}' -f '  Process Name', 'Memory  ') -ForegroundColor DarkCyan
Write-Host ('  {0}' -f ('-' * 46)) -ForegroundColor DarkCyan

$procs = Get-Process -ErrorAction SilentlyContinue |
Sort-Object -Property WorkingSet64 -Descending |
Select-Object -First $Top -Property Name, WorkingSet64

foreach ($proc in $procs) {
    $mb = [math]::Round($proc.WorkingSet64 / 1MB, 1)
    $color = if ($mb -gt 500) { 'Red' } elseif ($mb -gt 150) { 'Yellow' } else { 'Green' }
    Write-Host ('  {0,-28}' -f $proc.Name) -ForegroundColor White -NoNewline
    Write-Host ('{0,10} MB' -f $mb) -ForegroundColor $color
}

Write-Host ('  {0}' -f ('-' * 46)) -ForegroundColor DarkCyan
Write-Host ("  Snapshot: $(Get-Date -Format 'HH:mm:ss')") -ForegroundColor DarkGray
Write-Host ''
