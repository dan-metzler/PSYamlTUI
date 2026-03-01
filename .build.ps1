# .build.ps1
Import-Module InvokeBuild
. "$PSScriptRoot\Build\BuildFunctions.ps1"

#######################################
### DEFINE BUILD TASKS
#######################################

task CheckGitStatus {
    Test-GitStatus -ExpectedBranch 'main' 
}

task ModuleOutFolderCleanup {
    if (Test-Path "$PSScriptRoot\Output") {
        Remove-Item "$PSScriptRoot\Output\*" -Recurse -Force
    }
}

task BuildModule {
    $ok = & "$PSScriptRoot\Source\ModuleBuilder.ps1"
    if (-Not($ok)) { throw "ModuleBuilder.ps1 failed" }
}

task RunTests {
    Invoke-Pester -Script "$PSScriptRoot\Tests"
}


#######################################
### RUN BUILD TASKS
#######################################

task . CheckGitStatus, ModuleOutFolderCleanup, BuildModule, RunTests