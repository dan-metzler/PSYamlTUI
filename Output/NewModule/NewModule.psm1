#Region '.\Public\Get-CatFact.ps1' -1

function Get-CatFact {
    $result = Invoke-RestMethod -Uri "https://catfact.ninja/fact"
    return $result.fact
}
#EndRegion '.\Public\Get-CatFact.ps1' 5
