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

$result = [ordered]@{
    Environment = $Environment
    ServiceName = $service.Name
    DisplayName = $service.DisplayName
    Status      = $service.Status.ToString()
    StartType   = $service.StartType.ToString()
}

foreach ($key in $result.Keys) {
    Write-Output ('{0,-12}: {1}' -f $key, $result[$key])
}
