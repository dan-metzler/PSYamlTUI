param(
    [Parameter()]
    [string]$Path = 'C:\\Temp',

    [Parameter()]
    [int]$MaxItems = 10
)

function Invoke-ExampleCleanupPreview {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [ValidateRange(1, 200)]
        [int]$MaxItems = 10
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Output "Path '$Path' does not exist. Nothing to preview."
        return
    }

    Write-Host "Previewing up to $MaxItems item(s) in '$Path'." -ForegroundColor Yellow
    Get-ChildItem -Path $Path -File -ErrorAction SilentlyContinue |
        Select-Object -First $MaxItems -Property Name, Length, LastWriteTime
}

Invoke-ExampleCleanupPreview -Path $Path -MaxItems $MaxItems
