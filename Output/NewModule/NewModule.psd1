@{
    RootModule        = 'NewModule.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '11111111-1111-1111-1111-111111111111'
    Author            = 'Your Name'
    CompanyName       = 'Your Company'
    Copyright         = '(c) Your Name. All rights reserved.'
    Description       = 'New PowerShell module.'
    PowerShellVersion = '5.1'

    FunctionsToExport = 'Get-CatFact'
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
