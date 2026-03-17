param(
    [Parameter()]
    [string]$Path = '%TEMP%',

    [Parameter()]
    [ValidateRange(1, 200)]
    [int]$MaxItems = 10
)

$resolvedPath = [Environment]::ExpandEnvironmentVariables($Path)
if (-not (Test-Path -LiteralPath $resolvedPath)) {
    $fallbackPath = [System.IO.Path]::GetTempPath()
    if (Test-Path -LiteralPath $fallbackPath) {
        Write-Host "Path '$resolvedPath' was not found. Falling back to '$fallbackPath'." -ForegroundColor Yellow
        $resolvedPath = $fallbackPath
    }
    else {
        Write-Output "Path '$resolvedPath' does not exist. Nothing to preview."
        return
    }
}

Write-Host "Previewing up to $MaxItems item(s) in '$resolvedPath'." -ForegroundColor Yellow

$items = @(Get-ChildItem -Path $resolvedPath -File -ErrorAction SilentlyContinue |
    Select-Object -First $MaxItems -Property Name, Length, LastWriteTime, DirectoryName)

if ($null -eq $items -or $items.Count -eq 0) {
    Write-Host 'No top-level files were found. Searching one level deeper may be required on this machine.' -ForegroundColor DarkYellow

    $items = @(Get-ChildItem -Path $resolvedPath -File -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First $MaxItems -Property Name, Length, LastWriteTime, DirectoryName)
}

if ($null -eq $items -or $items.Count -eq 0) {
    Write-Host 'No files found. Showing mock cleanup candidates for demo output.' -ForegroundColor DarkYellow

    $items = @(
        [PSCustomObject]@{
            Name          = 'chrome_cache_001.tmp'
            Length        = 84213
            LastWriteTime = (Get-Date).AddDays(-2)
            DirectoryName = $resolvedPath
        },
        [PSCustomObject]@{
            Name          = 'installer_staging.log'
            Length        = 22491
            LastWriteTime = (Get-Date).AddDays(-7)
            DirectoryName = $resolvedPath
        },
        [PSCustomObject]@{
            Name          = 'orphaned_report.tmp'
            Length        = 6180
            LastWriteTime = (Get-Date).AddHours(-19)
            DirectoryName = $resolvedPath
        }
    ) | Select-Object -First $MaxItems
}

if ($null -eq $items -or $items.Count -eq 0) {
    Write-Output 'No files were found to preview.'
    return
}

$index = 1
foreach ($item in $items) {
    $size = [string]$item.Length
    $when = $item.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
    Write-Output ('[{0,2}] Name: {1}' -f $index, $item.Name)
    Write-Output ('     Size: {0} bytes' -f $size)
    Write-Output ('     When: {0}' -f $when)
    Write-Output ('     Path: {0}' -f $item.DirectoryName)
    Write-Output ''
    $index++
}
