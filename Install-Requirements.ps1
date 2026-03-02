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

