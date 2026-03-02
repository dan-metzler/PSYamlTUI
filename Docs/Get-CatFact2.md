---
external help file: NewModule-help.xml
Module Name: NewModule
online version: https://catfact.ninja
schema: 2.0.0
---

# Get-CatFact2

## SYNOPSIS
Retrieves a random cat fact from the catfact.ninja API.

## SYNTAX

```
Get-CatFact2
```

## DESCRIPTION
Queries the catfact.ninja REST API and returns a random cat fact as a string.
Requires an active internet connection.
The API does not require authentication.

## EXAMPLES

### EXAMPLE 1
```
Get-CatFact2
```

Returns a random cat fact string, such as "Cats sleep 16-20 hours a day."

### EXAMPLE 2
```
$fact = Get-CatFact2
Write-Host "Did you know? $fact"
```

Stores the returned fact in a variable for later use.

## PARAMETERS

## INPUTS

### None. This function does not accept pipeline input.
## OUTPUTS

### System.String
### Returns a string containing a random cat fact.
## NOTES
Author: MainUser
PowerShellVersion: PowerShell 5.1 or later recommended.
Requires internet connectivity to reach catfact.ninja API.

## RELATED LINKS

[https://catfact.ninja](https://catfact.ninja)

