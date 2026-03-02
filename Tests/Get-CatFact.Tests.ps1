Describe "Get-CatFact" {
    BeforeAll {
        # Import the module to bring Get-CatFact into scope
        Import-Module "$PSScriptRoot\..\Output\NewModule\NewModule.psd1" -Force
        
        # Mock must target the module scope in Pester 5
        Mock Invoke-RestMethod { @{ fact = "Cats sleep a lot" } } -ModuleName NewModule
    }

    It "Returns the fact from JSON response" {
        $fact = Get-CatFact
        $fact | Should -Be "Cats sleep a lot"
    }
}