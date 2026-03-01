function Test-GitStatus {
    <#
    .SYNOPSIS
        Verifies the current Git repository state before a build.

    .DESCRIPTION
        Checks that Git is installed, the current branch matches the expected branch,
        and there are no uncommitted or untracked changes.

    .PARAMETER ExpectedBranch
        The branch that must be checked out to pass the check. Defaults to 'main'.

    .EXAMPLE
        Test-GitStatus
        # Checks that the current branch is 'main' and there are no changes.

    .EXAMPLE
        Test-GitStatus -ExpectedBranch 'develop'
        # Checks that the current branch is 'develop' and there are no changes.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ExpectedBranch = 'main'
    )

    # Ensure Git is available
    Write-Verbose "Checking for git in PATH..."
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCmd) {
        throw "Git is not installed or not in PATH."
    }
    Write-Verbose "Found git: $($gitCmd.Path)"

    # Get current branch
    Write-Verbose "Resolving current branch..."
    $branch = git rev-parse --abbrev-ref HEAD
    Write-Verbose "Resolved branch: $branch"
    if ($branch -ne $ExpectedBranch) {
        throw "Build aborted: Current branch is '$branch'. Switch to '$ExpectedBranch'."
    }

    # Check for uncommitted or untracked changes
    Write-Verbose "Checking for uncommitted or untracked changes..."
    $status = git status --porcelain
    if ($status) {
        Write-Verbose "Git status (porcelain):`n$status"
        $lines = $status -split "`n"
        throw "Build aborted: You have uncommitted changes:`n$($lines -join "`n")"
    }

    Write-Verbose "Git check passed: on '$ExpectedBranch' branch with no uncommitted changes."
    return $true
}