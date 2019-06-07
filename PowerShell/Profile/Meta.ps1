function Disable-ProfileClear {
    [System.Environment]::SetEnvironmentVariable("PSProfileClear", 0, [System.EnvironmentVariableTarget]::User)
    $env:PSProfileClear = 0
}
function Enable-ProfileClear {
    [System.Environment]::SetEnvironmentVariable("PSProfileClear", 1, [System.EnvironmentVariableTarget]::User)
    $env:PSProfileClear = 1
}

if ($null -eq (Get-Command open -ErrorAction SilentlyContinue)) {
    New-Alias -Name open -Value Invoke-Item -Scope Global -Force
}

function Invoke-Profile {
    . $profile.CurrentUserAllHosts
}

function Disable-PoshGit {
    $env:DisablePoshGit = $true
}

function Enable-PoshGit {
    $env:DisablePoshGit = $false
}
