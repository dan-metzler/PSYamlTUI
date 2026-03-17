function global:Test-ExampleSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Environment,

        [Parameter(Mandatory)]
        [string]$Region
    )

    if ([string]::IsNullOrWhiteSpace($Environment)) {
        throw 'Hook failed: Environment was empty.'
    }

    if ([string]::IsNullOrWhiteSpace($Region)) {
        throw 'Hook failed: Region was empty.'
    }

    Write-Host "Session check passed for environment '$Environment' in region '$Region'." -ForegroundColor DarkCyan
    return $true
}

function global:Test-ExampleRole {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Reader', 'Operator', 'Admin')]
        [string]$RequiredRole,

        [Parameter(Mandatory)]
        [string]$CurrentUser
    )

    if ([string]::IsNullOrWhiteSpace($CurrentUser)) {
        throw 'Hook failed: CurrentUser was empty.'
    }

    Write-Host "Role check passed for user '$CurrentUser' with required role '$RequiredRole'." -ForegroundColor DarkCyan
    return $true
}

function global:Test-ExampleChangeWindow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Environment,

        [Parameter(Mandatory)]
        [string]$Region
    )

    if ($Environment -eq 'production') {
        Write-Host "Change window check passed for production in region '$Region'." -ForegroundColor DarkCyan
    }
    else {
        Write-Host "Change window check passed for non-production environment '$Environment'." -ForegroundColor DarkCyan
    }

    return $true
}

function global:Test-ExampleBlockedAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Reason
    )

    Write-Host "Blocked demo hook: $Reason" -ForegroundColor Yellow
    return $false
}

function global:Invoke-ExampleMockAuthRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool]$IsAuthenticated,

        [Parameter(Mandatory)]
        [string]$UserName
    )

    $content = @{
        id            = 1
        name          = $UserName
        email         = "$UserName@example.local"
        authenticated = $IsAuthenticated
    } | ConvertTo-Json -Compress

    return [PSCustomObject]@{
        StatusCode        = 200
        StatusDescription = 'OK'
        Content           = $content
        Headers           = @{ 'Content-Type' = 'application/json' }
    }
}

function global:Test-ExampleAuthRecovery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool]$IsAuthenticated,

        [Parameter(Mandatory)]
        [string]$UserName
    )

    $response = Invoke-ExampleMockAuthRequest -IsAuthenticated:$IsAuthenticated -UserName $UserName
    $data = $response.Content | ConvertFrom-Json

    if ([System.Convert]::ToBoolean($data.authenticated)) {
        Write-Host "Authentication check passed for user '$($data.name)'." -ForegroundColor DarkCyan
        return $true
    }

    Write-Host 'Authentication check failed. Prompting for credentials to continue.' -ForegroundColor Yellow
    $credential = Get-Credential -Message 'Enter credentials for the auth recovery demo.' -UserName $UserName
    if ($null -eq $credential) {
        Write-Host 'No credential entered. Hook remains false and action is blocked.' -ForegroundColor Yellow
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($credential.GetNetworkCredential().Password)) {
        Write-Host 'Empty password entered. Hook remains false and action is blocked.' -ForegroundColor Yellow
        return $false
    }

    $retryResponse = Invoke-ExampleMockAuthRequest -IsAuthenticated:$true -UserName $UserName
    $retryData = $retryResponse.Content | ConvertFrom-Json

    if ([System.Convert]::ToBoolean($retryData.authenticated)) {
        Write-Host "Authentication recovered for user '$($retryData.name)'. Continuing action." -ForegroundColor Green
        return $true
    }

    return $false
}

function global:Unregister-ExampleHooks {
    [CmdletBinding()]
    param()

    $names = @(
        'Test-ExampleSession',
        'Test-ExampleRole',
        'Test-ExampleChangeWindow',
        'Test-ExampleBlockedAction',
        'Invoke-ExampleMockAuthRequest',
        'Test-ExampleAuthRecovery',
        'Unregister-ExampleHooks'
    )

    foreach ($name in $names) {
        $path = "Function:\\$name"
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force
        }
    }
}
