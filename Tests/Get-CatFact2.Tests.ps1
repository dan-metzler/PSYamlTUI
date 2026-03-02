Describe "Get-CatFact2" {
    BeforeAll {
    # Import the module to bring Get-CatFact2 into scope
    $getPsdFile = Get-ChildItem -Path "$PSScriptRoot\..\Output\*.psd1" -Recurse | Select-Object -First 1
    
    if (-not($getPsdFile)) {
        throw "No .psd1 file found in the Output directory."
    }

    $ModuleDetails = $getPsdFile | Import-Module -PassThru -Force -ErrorAction Stop
        
        # Mock must target the module scope in Pester 5
        Mock Invoke-RestMethod { @{ fact = "Fat cats are lazy" } } -ModuleName $ModuleDetails.Name
    }

    It "Returns the fact from JSON response" {
        $fact = Get-CatFact2
        $fact | Should -Be "Fat cats are lazy"
    }
}