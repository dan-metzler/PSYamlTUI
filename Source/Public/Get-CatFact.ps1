function Get-CatFact {
    $result = Invoke-RestMethod -Uri "https://catfact.ninja/fact"
    return $result.fact
}