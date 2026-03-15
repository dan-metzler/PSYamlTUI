[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('cpu', 'memory', 'name')]
    [string]$SortBy,

    [Parameter()]
    [ValidateRange(1, 50)]
    [int]$Top = 10
)

$sortProp = switch ($SortBy) {
    'cpu' { 'CPU' }
    'memory' { 'WorkingSet' }
    'name' { 'ProcessName' }
}

Get-Process -ErrorAction SilentlyContinue |
Sort-Object $sortProp -Descending |
Select-Object -First $Top |
ForEach-Object {
    $mem = [Math]::Round($_.WorkingSet / 1MB, 1)
    $cpu = if ($null -ne $_.CPU) { [Math]::Round($_.CPU, 1) } else { 0 }
    Write-Host ("  {0,-30} {1,10} {2,14}" -f $_.ProcessName, $cpu, $mem) -ForegroundColor White
}
Write-Host ""
