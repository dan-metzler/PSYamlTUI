$requiredModules = @(
    @{ ModuleName = 'ModuleBuilder'; MinimumVersion = '3.1.8'; MaximumVersion = '4.999.999' }
    @{ ModuleName = 'Pester'; MinimumVersion = '3.4.0'; MaximumVersion = '5.999.999' }
    @{ ModuleName = 'InvokeBuild'; MinimumVersion = '5.14.23'; MaximumVersion = '6.999.999' }
    @{ ModuleName = 'platyPS'; MinimumVersion = '0.14.2'; MaximumVersion = '1.999.999' }
)

foreach ($moduleItem in $requiredModules) {

    try {
        Get-InstalledModule -Name $($moduleItem.ModuleName) -MinimumVersion $($moduleItem.MinimumVersion) -MaximumVersion $($moduleItem.MaximumVersion) -ErrorAction Stop | Select-Object Name, Version
    }
    catch {
        Write-Host "Installing $($moduleItem.ModuleName)"
        Install-Module -Name $($moduleItem.ModuleName) -MinimumVersion $($moduleItem.MinimumVersion) -MaximumVersion $($moduleItem.MaximumVersion) -Scope CurrentUser -Force
    }
}

# -- YamlDotNet.dll ------------------------------------------------------------
# Downloads the YamlDotNet NuGet package and extracts the correct .dll into
# Source/lib/ for use by PSYamlTUI at runtime. Targets netstandard2.0 which
# is compatible with both PS 5.1 (.NET Framework 4.5+) and PS 7+ (.NET Core).

$yamlDotNetVersion = '16.3.0'
$libDir = Join-Path $PSScriptRoot 'Source' 'lib'
$dllDestination = Join-Path $libDir 'YamlDotNet.dll'

if (Test-Path -LiteralPath $dllDestination) {
    Write-Host "YamlDotNet.dll already present: $dllDestination"
}
else {
    Write-Host "Downloading YamlDotNet $yamlDotNetVersion from NuGet..."

    $null = New-Item -ItemType Directory -Path $libDir -Force

    $nupkgUrl = "https://www.nuget.org/api/v2/package/YamlDotNet/$yamlDotNetVersion"
    $nupkgTemp = Join-Path ([System.IO.Path]::GetTempPath()) "YamlDotNet.$yamlDotNetVersion.nupkg"

    try {
        $wc = [System.Net.WebClient]::new()
        $wc.DownloadFile($nupkgUrl, $nupkgTemp)
        $wc.Dispose()
    }
    catch {
        throw "Failed to download YamlDotNet from NuGet: $_"
    }

    # .nupkg files are ZIP archives — extract with .NET's ZipFile
    Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
    $zip = [System.IO.Compression.ZipFile]::OpenRead($nupkgTemp)

    try {
        # Prefer netstandard2.0 for widest PS 5.1 + PS 7 compatibility
        $dllEntry = $zip.Entries | Where-Object { $_.FullName -like 'lib/netstandard2.0/YamlDotNet.dll' } |
        Select-Object -First 1

        # Fallback to net45 if netstandard2.0 isn't present (older package versions)
        if ($null -eq $dllEntry) {
            $dllEntry = $zip.Entries | Where-Object { $_.FullName -like 'lib/net45*/YamlDotNet.dll' } |
            Select-Object -First 1
        }

        if ($null -eq $dllEntry) {
            throw "Could not locate YamlDotNet.dll inside the NuGet package. Entries found:`n$($zip.Entries.FullName -join "`n")"
        }

        $stream = $dllEntry.Open()
        $fileStream = [System.IO.File]::Create($dllDestination)
        try {
            $stream.CopyTo($fileStream)
        }
        finally {
            $fileStream.Dispose()
            $stream.Dispose()
        }
    }
    finally {
        $zip.Dispose()
        Remove-Item -LiteralPath $nupkgTemp -Force -ErrorAction SilentlyContinue
    }

    Write-Host "YamlDotNet.dll installed to: $dllDestination"
}


