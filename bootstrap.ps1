# Setup my execution policy for both the 64 bit and 32 bit shells
Set-ExecutionPolicy Unrestricted
Start-Job -RunAs32 { Set-ExecutionPolicy Unrestricted } | Receive-Job -Wait

# Install the latest stable ChefDK
if ($null -eq (Get-Command chef-client*)) {
    Invoke-RestMethod 'https://omnitruck.chef.io/install.ps1' | Invoke-Expression
    Install-Project chefdk -verbose
}

# Install Chocolatey
if ($null -eq (Get-Command choco*)) {
    Invoke-Expression ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
    choco feature enable -n allowGlobalConfirmation
}

<#
# Get a basic setup recipe
Invoke-RestMethod 'https://gist.githubusercontent.com/smurawski/da67107b5efd00876af7bb0c8cfe8453/raw' | Out-File -Encoding ASCII -Filepath C:\basic.rb

# Use Chef Apply to setup
chef-apply C:\basic.rb
#>

#region: Manage $profile.CurrentUserAllHosts contents
if (-not (Test-Path $profile.CurrentUserAllHosts)) {
    &$log "Creating CurrentUserAllHosts file" "Profile" "Maint"
    New-Item $profile.CurrentUserAllHosts -Force
}
$_pPath = [System.IO.Path]::Combine($PSScriptRoot,"PowerShell","Profile","profile.ps1")
@"
. '$_pPath'
function Edit-CodeProfile {
    [CmdletBinding()]
    Param (
        [parameter(Mandatory = `$false,Position = 0)]
        [String[]]
        `$Path = "$_pPath",
        [parameter(Mandatory = `$false,Position = 1)]
        [Switch]
        `$Folder
    )
    if (`$Folder) {
        code "$PSScriptRoot"
    }
    else {
        code `$Path
    }
}
"@ | Set-Content $profile.CurrentUserAllHosts -Force
#endregion: Manage $profile.CurrentUserAllHosts contents
