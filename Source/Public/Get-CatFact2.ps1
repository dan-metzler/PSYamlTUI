function Get-CatFact2 {
    $result = Invoke-RestMethod -Uri "https://catfact.ninja/fact"
    return $result.fact
}