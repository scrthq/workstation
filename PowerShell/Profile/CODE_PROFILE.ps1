$global:PSProfileConfig = @{
    _internal       = @{
        ProfileLoadStart = Get-Date
    }
    Settings        = @{
        Prompt                = 'Slim'
        PSVersionStringLength = 3
    }
    Variables       = @{
        Environment = @{
            USERPROFILE = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
        }
        Global      = @{
            CodeProfile                    = $PSScriptRoot
            PathAliasDirectorySeparator    = [System.IO.Path]::DirectorySeparatorChar
            AltPathAliasDirectorySeparator = [char]0xe0b1
        }
    }
    GitPaths        = @{
        Work     = 'WorkGit'
        Personal = 'ScrtGit'
        Other    = 'E:\Git'
    }
    PathAliases     = @(
        @{
            Alias = '~'
            Path  = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
        }
    )
    GistsToInvoke   = @(
        @{
            Id       = '6b2dfc7efc459399c872d23a663d7914'
            Files    = @('__init__.ps1','_Meta.ps1','_DemoTools.ps1','_FunTools.ps1','_Prompts.ps1','_PSReadlineSettings.ps1')
            Metadata = @{
                Description = 'PowerShell Profile Components'
            }
        }
    )
    ModulesToImport = @(
        'PSChef'
        'PSToolbelt'
        'MyConfig'
    )
}

$log = {
    Param(
        $Message,
        $Section = "Info",
        $Action = "Log",
        $Start = $(if ($global:PSProfileConfig._internal.ProfileLoadStart){$global:PSProfileConfig._internal.ProfileLoadStart}else{Get-Date})
    )
    $now = Get-Date
    $ls = if ($null -eq $script:LastProfileCommandTime) {
        $now - $Start
    }
    else {
        $now - $script:LastProfileCommandTime
    }
    $ts = $now - $Start
    Write-Host -ForegroundColor Cyan ("[L+{0:00}.{1:000}s] [T+{2:00}.{3:000}s] [{4}] [{5}] {6}" -f ([Math]::Floor($ls.TotalSeconds)),$ls.Milliseconds,([Math]::Floor($ts.TotalSeconds)),$ts.Milliseconds,"$Section".PadRight(10,'.'),"$Action".PadRight(9,'.'),$Message)
    $script:LastProfileCommandTime = Get-Date
}

Write-Host -ForegroundColor Yellow "
[LastTime.] [TotalTime] [Section...] [Action...] Log Message...
----------- ----------- ------------ ----------- ---------------------------------------------------------------------"

#region: Apply the $global:PSProfileConfig
foreach ($var in $global:PSProfileConfig.Variables.Environment.Keys) {
    &$log "`$env:$var = '$($global:PSProfileConfig.Variables.Environment[$var])'" "Variable" "Set"
    Set-Item "Env:\$var" -Value $global:PSProfileConfig.Variables.Environment[$var] -Force
}
foreach ($var in $global:PSProfileConfig.Variables.Global.Keys) {
    &$log "`$global:$var = '$($global:PSProfileConfig.Variables.Global[$var])'" "Variable" "Set"
    Set-Variable -Name $var -Value $global:PSProfileConfig.Variables.Global[$var] -Scope Global -Force
}
$aliasMapJson = @{ }
foreach ($category in $global:PSProfileConfig.GitPaths.Keys) {
    $aliasIcon = switch ($category) {
        Work {
            '$'
        }
        Personal {
            '@'
        }
        default {
            '#'
        }
    }
    if ($global:PSProfileConfig.GitPaths[$category] -notmatch [RegEx]::Escape(([System.IO.Path]::DirectorySeparatorChar))) {
        $paired = $false
        $env:USERPROFILE,$PWD.Path,$PWD.Drive.Root | ForEach-Object {
            if (-not $paired) {
                $gitPath = Join-Path $_ $global:PSProfileConfig.GitPaths[$category]
                if (Test-Path $gitPath) {
                    $paired = $true
                }
            }
        }
    }
    else {
        $gitPath = $global:PSProfileConfig.GitPaths[$category]
    }
    &$log "'$($aliasIcon)git' = '$($gitPath)'" "PathAlias" "Set"
    $aliasMapJson["$($aliasIcon)git"] = $gitPath
}
foreach ($alias in $global:PSProfileConfig.PathAliases) {
    &$log "'$($alias['Alias'])' = '$($alias['Path'])'" "PathAlias" "Set"
    $aliasMapJson[$alias['Alias']] = $alias['Path']
}
$global:PSProfileConfig['_internal']['PathAliasMap'] = $aliasMapJson

$global:PSProfileConfig['_internal']['GitPathMap'] = @{ CodeProfile = $global:CodeProfile }
$global:PSProfileConfig['_internal']['PSBuildPathMap'] = @{}
foreach ($key in $global:PSProfileConfig.GitPaths.Keys) {
    $fullPath = if (Test-Path ($global:PSProfileConfig.GitPaths[$key])) {
        $global:PSProfileConfig.GitPaths[$key]
    }
    elseif (Test-Path (Join-Path "~" $global:PSProfileConfig.GitPaths[$key])) {
        Join-Path "~" $global:PSProfileConfig.GitPaths[$key]
    }
    elseif (Test-Path (Join-Path $PWD.Drive.Root $global:PSProfileConfig.GitPaths[$key])) {
        Join-Path $PWD.Drive.Root $global:PSProfileConfig.GitPaths[$key]
    }
    else {
        "???<$($global:PSProfileConfig.GitPaths[$key])>"
    }
    &$log "$key[$fullPath]" "GitRepos" "Discover"
    $g = 0
    $b = 0
    if ($fullPath -notmatch '^\?\?\?' -and (Test-Path $fullPath)) {
        Get-ChildItem $fullPath -Recurse -Filter '.git' -Directory -Force | ForEach-Object {
            $global:PSProfileConfig['_internal']['GitPathMap'][$_.Parent.BaseName] = $_.Parent.FullName
            $g++
            if (Test-Path (Join-Path $_.Parent.FullName "build.ps1")) {
                $global:PSProfileConfig['_internal']['PSBuildPathMap'][$_.Parent.BaseName] = $_.Parent.FullName
                $b++
            }
        }
    }
    &$log "$key[$fullPath] :: $g git | $b build" "GitRepos" "Report"
}

if (-not (Test-Path $profile.CurrentUserAllHosts)) {
    &$log "Creating CurrentUserAllHosts file" "Profile" "Maint"
    New-Item $profile.CurrentUserAllHosts -Force
}

$_psProfilePath = Join-Path $env:USERPROFILE '.psprofile'
$_psProfileSettingsPath = Join-Path $_psProfilePath 'settings.json'
if (-not (Test-Path $_psProfilePath )) {
    &$log "Creating .psprofile folder" "Profile" "Maint"
    New-Item $_psProfilePath  -ItemType Directory -Force
}
if (-not (Test-Path $_psProfileSettingsPath)) {
    if ($null -ne $global:PSProfileConfig.Settings -and $null -ne $global:PSProfileConfig.Settings.Keys) {
        &$log "Creating settings.json in .psprofile folder" "Profile" "Maint"
        $global:PSProfileConfig.Settings | ConvertTo-Json -Depth 5 -Compress | Set-Content $_psProfileSettingsPath -Force
    }
}
else {
    &$log "Importing settings.json from .psprofile folder" "Profile" "Maint"
    if ($null -ne $global:PSProfileConfig.Settings) {
        $global:PSProfileConfig.Settings = @{}
    }
    $private:_settings = Get-Content $_psProfileSettingsPath -Raw | ConvertFrom-Json
    foreach ($prop in $private:_settings.PSObject.Properties.Name) {
        $global:PSProfileConfig.Settings[$prop] = $private:_settings.$prop
    }
}

#region: Set prompt
if (-not $env:DemoInProgress) {
    $global:PSProfileConfig.ModulesToImport | ForEach-Object {
        &$log $_ "Module" "Import"
        Import-Module $_ -ErrorAction SilentlyContinue
    }
    if ($global:PSProfileConfig.Settings.Prompt) {
        &$log "Setting prompt to $($global:PSProfileConfig.Settings.Prompt)" "Profile" "Maint"
        Switch-Prompt -Prompt $global:PSProfileConfig.Settings.Prompt
    }
}
else {
    demo
}
#endregion: Set prompt

Write-Host ("Loading personal profile alone took {0}ms." -f ([Math]::Round(((Get-Date) - $global:PSProfileConfig._internal.ProfileLoadStart).TotalMilliseconds,0)))
$global:PSProfileConfig = @{
    _internal       = @{
        ProfileLoadStart = Get-Date
    }
    Settings        = @{
        Prompt                = 'Slim'
        PSVersionStringLength = 3
    }
    Variables       = @{
        Environment = @{
            USERPROFILE = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
        }
        Global      = @{
            CodeProfile                    = $PSScriptRoot
            PathAliasDirectorySeparator    = [System.IO.Path]::DirectorySeparatorChar
            AltPathAliasDirectorySeparator = [char]0xe0b1
        }
    }
    GitPaths        = @{
        Work     = 'WorkGit'
        Personal = 'ScrtGit'
        Other    = 'E:\Git'
    }
    PathAliases     = @(
        @{
            Alias = '~'
            Path  = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
        }
    )
    GistsToInvoke   = @(
        @{
            Id       = '6b2dfc7efc459399c872d23a663d7914'
            Files    = @('__init__.ps1','_Meta.ps1','_DemoTools.ps1','_FunTools.ps1','_Prompts.ps1','_PSReadlineSettings.ps1')
            Metadata = @{
                Description = 'PowerShell Profile Components'
            }
        }
    )
    ModulesToImport = @(
        'PSChef'
        'PSToolbelt'
        'MyConfig'
    )
}

$log = {
    Param(
        $Message,
        $Section = "Info",
        $Action = "Log",
        $Start = $(if ($global:PSProfileConfig._internal.ProfileLoadStart){$global:PSProfileConfig._internal.ProfileLoadStart}else{Get-Date})
    )
    $now = Get-Date
    $ls = if ($null -eq $script:LastProfileCommandTime) {
        $now - $Start
    }
    else {
        $now - $script:LastProfileCommandTime
    }
    $ts = $now - $Start
    Write-Host -ForegroundColor Cyan ("[L+{0:00}.{1:000}s] [T+{2:00}.{3:000}s] [{4}] [{5}] {6}" -f ([Math]::Floor($ls.TotalSeconds)),$ls.Milliseconds,([Math]::Floor($ts.TotalSeconds)),$ts.Milliseconds,"$Section".PadRight(10,'.'),"$Action".PadRight(9,'.'),$Message)
    $script:LastProfileCommandTime = Get-Date
}

Write-Host -ForegroundColor Yellow "
[LastTime.] [TotalTime] [Section...] [Action...] Log Message...
----------- ----------- ------------ ----------- ---------------------------------------------------------------------"

#region: Apply the $global:PSProfileConfig
foreach ($var in $global:PSProfileConfig.Variables.Environment.Keys) {
    &$log "`$env:$var = '$($global:PSProfileConfig.Variables.Environment[$var])'" "Variable" "Set"
    Set-Item "Env:\$var" -Value $global:PSProfileConfig.Variables.Environment[$var] -Force
}
foreach ($var in $global:PSProfileConfig.Variables.Global.Keys) {
    &$log "`$global:$var = '$($global:PSProfileConfig.Variables.Global[$var])'" "Variable" "Set"
    Set-Variable -Name $var -Value $global:PSProfileConfig.Variables.Global[$var] -Scope Global -Force
}
$aliasMapJson = @{ }
foreach ($category in $global:PSProfileConfig.GitPaths.Keys) {
    $aliasIcon = switch ($category) {
        Work {
            '$'
        }
        Personal {
            '@'
        }
        default {
            '#'
        }
    }
    if ($global:PSProfileConfig.GitPaths[$category] -notmatch [RegEx]::Escape(([System.IO.Path]::DirectorySeparatorChar))) {
        $paired = $false
        $env:USERPROFILE,$PWD.Path,$PWD.Drive.Root | ForEach-Object {
            if (-not $paired) {
                $gitPath = Join-Path $_ $global:PSProfileConfig.GitPaths[$category]
                if (Test-Path $gitPath) {
                    $paired = $true
                }
            }
        }
    }
    else {
        $gitPath = $global:PSProfileConfig.GitPaths[$category]
    }
    &$log "'$($aliasIcon)git' = '$($gitPath)'" "PathAlias" "Set"
    $aliasMapJson["$($aliasIcon)git"] = $gitPath
}
foreach ($alias in $global:PSProfileConfig.PathAliases) {
    &$log "'$($alias['Alias'])' = '$($alias['Path'])'" "PathAlias" "Set"
    $aliasMapJson[$alias['Alias']] = $alias['Path']
}
$global:PSProfileConfig['_internal']['PathAliasMap'] = $aliasMapJson

$global:PSProfileConfig['_internal']['GitPathMap'] = @{ CodeProfile = $global:CodeProfile }
$global:PSProfileConfig['_internal']['PSBuildPathMap'] = @{}
foreach ($key in $global:PSProfileConfig.GitPaths.Keys) {
    $fullPath = if (Test-Path ($global:PSProfileConfig.GitPaths[$key])) {
        $global:PSProfileConfig.GitPaths[$key]
    }
    elseif (Test-Path (Join-Path "~" $global:PSProfileConfig.GitPaths[$key])) {
        Join-Path "~" $global:PSProfileConfig.GitPaths[$key]
    }
    elseif (Test-Path (Join-Path $PWD.Drive.Root $global:PSProfileConfig.GitPaths[$key])) {
        Join-Path $PWD.Drive.Root $global:PSProfileConfig.GitPaths[$key]
    }
    else {
        "???<$($global:PSProfileConfig.GitPaths[$key])>"
    }
    &$log "$key[$fullPath]" "GitRepos" "Discover"
    $g = 0
    $b = 0
    if ($fullPath -notmatch '^\?\?\?' -and (Test-Path $fullPath)) {
        Get-ChildItem $fullPath -Recurse -Filter '.git' -Directory -Force | ForEach-Object {
            $global:PSProfileConfig['_internal']['GitPathMap'][$_.Parent.BaseName] = $_.Parent.FullName
            $g++
            if (Test-Path (Join-Path $_.Parent.FullName "build.ps1")) {
                $global:PSProfileConfig['_internal']['PSBuildPathMap'][$_.Parent.BaseName] = $_.Parent.FullName
                $b++
            }
        }
    }
    &$log "$key[$fullPath] :: $g git | $b build" "GitRepos" "Report"
}

if (-not (Test-Path $profile.CurrentUserAllHosts)) {
    &$log "Creating CurrentUserAllHosts file" "Profile" "Maint"
    New-Item $profile.CurrentUserAllHosts -Force
}

$_psProfilePath = Join-Path $env:USERPROFILE '.psprofile'
$_psProfileSettingsPath = Join-Path $_psProfilePath 'settings.json'
if (-not (Test-Path $_psProfilePath )) {
    &$log "Creating .psprofile folder" "Profile" "Maint"
    New-Item $_psProfilePath  -ItemType Directory -Force
}
if (-not (Test-Path $_psProfileSettingsPath)) {
    if ($null -ne $global:PSProfileConfig.Settings -and $null -ne $global:PSProfileConfig.Settings.Keys) {
        &$log "Creating settings.json in .psprofile folder" "Profile" "Maint"
        $global:PSProfileConfig.Settings | ConvertTo-Json -Depth 5 -Compress | Set-Content $_psProfileSettingsPath -Force
    }
}
else {
    &$log "Importing settings.json from .psprofile folder" "Profile" "Maint"
    if ($null -ne $global:PSProfileConfig.Settings) {
        $global:PSProfileConfig.Settings = @{}
    }
    $private:_settings = Get-Content $_psProfileSettingsPath -Raw | ConvertFrom-Json
    foreach ($prop in $private:_settings.PSObject.Properties.Name) {
        $global:PSProfileConfig.Settings[$prop] = $private:_settings.$prop
    }
}

#region: Set prompt
if (-not $env:DemoInProgress) {
    $global:PSProfileConfig.ModulesToImport | ForEach-Object {
        &$log $_ "Module" "Import"
        Import-Module $_ -ErrorAction SilentlyContinue
    }
    if ($global:PSProfileConfig.Settings.Prompt) {
        &$log "Setting prompt to $($global:PSProfileConfig.Settings.Prompt)" "Profile" "Maint"
        Switch-Prompt -Prompt $global:PSProfileConfig.Settings.Prompt
    }
}
else {
    demo
}
#endregion: Set prompt

Write-Host ("Loading personal profile alone took {0}ms." -f ([Math]::Round(((Get-Date) - $global:PSProfileConfig._internal.ProfileLoadStart).TotalMilliseconds,0)))
