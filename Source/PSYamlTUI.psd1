@{
    RootModule        = 'PSYamlTUI.psm1'
    ModuleVersion     = '0.0.1'
    GUID              = '3d5cea06-0fe1-4fb0-a6be-b103fd895367'
    Author            = 'Dan Metzler'
    CompanyName       = 'Community'
    Copyright         = '(c) Dan Metzler. All rights reserved.'
    Description       = 'YAML-powered terminal UI menus for PowerShell. Define once, navigate anywhere - with recursive submenus, automatic terminal detection, and safe script execution built in.'
    PowerShellVersion = '5.1'

    PrivateData       = @{
        PSData = @{
            Tags         = @('YAML', 'TUI', 'Menu', 'Terminal', 'UI')
            LicenseUri   = 'https://github.com/dan-metzler/PSYamlTUI/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/dan-metzler/PSYamlTUI'
            ReleaseNotes = ''
        }
    }

    FunctionsToExport = @('Start-Menu')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}