$tempPaths = @(
    $env:TEMP,
    "$env:LOCALAPPDATA\Temp"
)

$results = foreach ($path in $tempPaths) {
    if (-not (Test-Path -Path $path)) { continue }

    $files = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    $size = ($files | Measure-Object -Property Length -Sum).Sum

    [PSCustomObject]@{
        Path      = $path
        FileCount = $files.Count
        SizeBytes = $size
        SizeMB    = [math]::Round($size / 1MB, 2)
        SizeGB    = [math]::Round($size / 1GB, 3)
    }
}

$results | Format-Table -AutoSize

$totalBytes = ($results | Measure-Object -Property SizeBytes -Sum).Sum
Write-Host "Total: $([math]::Round($totalBytes / 1GB, 3)) GB  ($([math]::Round($totalBytes / 1MB, 2)) MB)" -ForegroundColor Cyan