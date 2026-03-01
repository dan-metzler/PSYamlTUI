Describe "Get-CatFact" {
    It "Returns the fact from JSON response" {
        Mock Invoke-RestMethod { @{ fact = "Cats sleep a lot" } }
        $fact = Get-CatFact
        $fact | Should -Be "Cats sleep a lot"
    }
}