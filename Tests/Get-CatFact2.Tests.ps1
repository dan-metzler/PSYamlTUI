Describe "Get-CatFact2" {
    It "Returns the fact from JSON response" {
        Mock Invoke-RestMethod { @{ fact = "Fat cats are lazy" } }
        $fact = Get-CatFact2
        $fact | Should -Be "Fat cats are lazy"
    }
}