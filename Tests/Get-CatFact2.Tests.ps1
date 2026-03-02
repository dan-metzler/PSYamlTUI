Describe "Get-CatFact2" {
    BeforeAll {
        # Import the module to bring Get-CatFact2 into scope
        Import-Module "$PSScriptRoot\..\Output\NewModule\NewModule.psd1" -Force
        
        # Mock must target the module scope in Pester 5
        Mock Invoke-RestMethod { @{ fact = "Fat cats are lazy" } } -ModuleName NewModule
    }

    It "Returns the fact from JSON response" {
        $fact = Get-CatFact2
        $fact | Should -Be "Fat cats are lazy"
    }
}