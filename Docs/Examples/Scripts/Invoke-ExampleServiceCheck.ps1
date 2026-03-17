param(
    [Parameter()]
    [string]$ServiceName = 'Spooler',

    [Parameter()]
    [string]$Environment = 'dev'
)

function Invoke-ExampleServiceCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ServiceName,

        [Parameter(Mandatory)]
        [string]$Environment
    )

    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($null -eq $service) {
        Write-Output "Service '$ServiceName' was not found in environment '$Environment'."
        return
    }

    Write-Output ([PSCustomObject]@{
        Environment = $Environment
        ServiceName = $service.Name
        DisplayName = $service.DisplayName
        Status      = $service.Status.ToString()
        StartType   = $service.StartType.ToString()
    })
}

Invoke-ExampleServiceCheck -ServiceName $ServiceName -Environment $Environment
