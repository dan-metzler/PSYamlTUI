function Get-CatFact {
    <#
    .SYNOPSIS
    Retrieves a random cat fact from the catfact.ninja API.

    .DESCRIPTION
    Queries the catfact.ninja REST API and returns a random cat fact as a string.
    Requires an active internet connection. The API does not require authentication.

    .EXAMPLE
    Get-CatFact

    Returns a random cat fact string, such as "Cats sleep 16-20 hours a day."

    .EXAMPLE
    $fact = Get-CatFact
    Write-Host "Did you know? $fact"

    Stores the returned fact in a variable for later use.

    .INPUTS
    None. This function does not accept pipeline input.

    .OUTPUTS
    System.String
    Returns a string containing a random cat fact.

    .NOTES
    Author: MainUser
    PowerShellVersion: PowerShell 5.1 or later recommended.
    Requires internet connectivity to reach catfact.ninja API.

    .LINK
    https://catfact.ninja
    #>
    
    $result = Invoke-RestMethod -Uri "https://catfact.ninja/fact"
    return $result.fact
}