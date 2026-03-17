$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [System.Security.Principal.WindowsPrincipal]$identity
$isAdmin = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
$roleText = if ($isAdmin) { 'Administrator' } else { 'Standard User' }
$roleColor = if ($isAdmin) { 'Yellow' } else { 'Green' }

Write-Host ''
Write-Host '  Active Session' -ForegroundColor Cyan
Write-Host ('  {0}' -f ('-' * 46)) -ForegroundColor DarkCyan
Write-Host '  Username      : ' -ForegroundColor DarkGray -NoNewline
Write-Host $identity.Name -ForegroundColor White
Write-Host '  Auth Type     : ' -ForegroundColor DarkGray -NoNewline
Write-Host $identity.AuthenticationType -ForegroundColor White
Write-Host '  Role          : ' -ForegroundColor DarkGray -NoNewline
Write-Host $roleText -ForegroundColor $roleColor
Write-Host ''

$groups = $identity.Groups |
ForEach-Object {
    try { $_.Translate([System.Security.Principal.NTAccount]).Value }
    catch { $_.Value }
} |
Where-Object { $_ -match 'Administrators|Users|Remote|Power' } |
Select-Object -First 6

if ($null -ne $groups -and @($groups).Count -gt 0) {
    Write-Host '  Relevant Groups' -ForegroundColor DarkCyan
    foreach ($g in $groups) {
        $gColor = if ($g -match 'Admin') { 'Yellow' } else { 'Gray' }
        Write-Host ('    - {0}' -f $g) -ForegroundColor $gColor
    }
}

Write-Host ('  {0}' -f ('-' * 46)) -ForegroundColor DarkCyan
Write-Host ("  Checked at: $(Get-Date -Format 'HH:mm:ss')") -ForegroundColor DarkGray
Write-Host ''
