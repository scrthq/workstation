#region: Add activity header and anonymous functions
$Host.UI.RawUI.WindowTitle = 'PS {0}' -f ($PSVersionTable.PSVersion.ToString().Split('.',3).ForEach({"$_".Substring(0,1)}) -join ".")
$logOutput = -not (Test-Path ([System.IO.Path]::Combine($PSScriptRoot,'SENSITIVE','nolog')))
if ($logOutput) {
    Write-Host -ForegroundColor Yellow "
[LastTime.] [TotalTime] [Section...] [Action...] Log Message...
----------- ----------- ------------ ----------- ---------------------------------------------------------------------"
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
}
#endregion: Add activity header and anonymous functions

#region: Load CONFIG.ps1 to fill out $global:PSProfileConfig
try {
    foreach ($configFile in (Get-ChildItem $PSScriptRoot -Filter "CONFIG*ps1" -ErrorAction Stop | Sort-Object {$_.BaseName.Length} -Descending)) {
        if ($logOutput) {
            &$log ". .\$($configFile.Name)" "Script" "Invoke"
        }
        . $configFile.FullName
    }
}
catch {
    $global:PSProfileConfig = @{
        _internal       = @{}
        Settings        = @{}
        Variables       = @{}
        GitPaths        = @{}
        PathAliases     = @()
        GistsToInvoke   = @()
        ModulesToImport = @()
    }
}
if (($global:PSProfileConfig.PathAliases | ForEach-Object {$_.Alias}) -notcontains '~') {
    $global:PSProfileConfig.PathAliases += @{Alias = '~';Path  = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)}
}
if (($global:PSProfileConfig.Variables.Environment).Keys -notcontains 'USERPROFILE') {
    $global:PSProfileConfig.Variables.Environment['USERPROFILE'] = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
}
if (($global:PSProfileConfig.Variables.Global).Keys -notcontains 'CodeProfile') {
    $global:PSProfileConfig.Variables.Global['CodeProfile'] = $PSScriptRoot
}
#endregion: Load CONFIG.ps1 to fill out $global:PSProfileConfig

#region: Set session variables from config
foreach ($varType in $global:PSProfileConfig.Variables.Keys) {
    switch ($varType) {
        Environment {
            foreach ($var in $global:PSProfileConfig.Variables[$varType].Keys) {
                if ($logOutput) {
                    &$log "`$env:$var = '$($global:PSProfileConfig.Variables[$varType][$var])'" "Variable" "Set"
                }
                Set-Item "Env:\$var" -Value $global:PSProfileConfig.Variables[$varType][$var] -Force
            }
        }
        default {
            foreach ($var in $global:PSProfileConfig.Variables.Global.Keys) {
                if ($logOutput) {
                    &$log "`$$($varType.ToLower()):$var = '$($global:PSProfileConfig.Variables[$varType][$var])'" "Variable" "Set"
                }
                Set-Variable -Name $var -Value $global:PSProfileConfig.Variables[$varType][$var] -Scope $varType -Force
            }
        }
    }
}
#endregion: Set session variables from config

#region: Fill out PathAliasMap
$global:PSProfileConfig['_internal']['PathAliasMap'] = @{ }
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
        $env:USERPROFILE,$PWD.Path,$PWD.Drive.Root | ForEach-Object {
            $gitPath = Join-Path $_ $global:PSProfileConfig.GitPaths[$category]
            if (Test-Path $gitPath) {
                break
            }
        }
    }
    else {
        $gitPath = $global:PSProfileConfig.GitPaths[$category]
    }
    if ($logOutput) {
        &$log "'$($aliasIcon)git' = '$($gitPath)'" "PathAlias" "Set"
    }
    $global:PSProfileConfig['_internal']['PathAliasMap']["$($aliasIcon)git"] = $gitPath
}
foreach ($alias in $global:PSProfileConfig.PathAliases) {
    if ($logOutput) {
        &$log "'$($alias['Alias'])' = '$($alias['Path'])'" "PathAlias" "Set"
    }
    $global:PSProfileConfig['_internal']['PathAliasMap'][$alias['Alias']] = $alias['Path']
}
#endregion: Fill out PathAliasMap

#region: Fill out GitPathMap and PSBuildPathMap
$global:PSProfileConfig['_internal']['GitPathMap'] = @{ CodeProfile = $PSScriptRoot }
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
    $g = 0
    $b = 0
    if ($fullPath -notmatch '^\?\?\?' -and (Test-Path $fullPath)) {
        Get-ChildItem $fullPath -Recurse -Filter '.git' -Directory -Depth 4 -Force | ForEach-Object {
            $global:PSProfileConfig['_internal']['GitPathMap'][$_.Parent.BaseName] = $_.Parent.FullName
            $g++
            if (Test-Path (Join-Path $_.Parent.FullName "build.ps1")) {
                $global:PSProfileConfig['_internal']['PSBuildPathMap'][$_.Parent.BaseName] = $_.Parent.FullName
                $b++
            }
        }
    }
    if ($logOutput) {
        &$log "$key[$fullPath] :: $g git | $b build" "GitRepos" "Report"
    }
}
#endregion: Fill out GitPathMap and PSBuildPathMap

#region: Manage local settings file for settings persistence between sessions
$global:PSProfileConfig._internal['ProfileSettingsPath'] = [System.IO.Path]::Combine($PSScriptRoot,'SENSITIVE','settings.json')
if (-not (Test-Path $global:PSProfileConfig._internal['ProfileSettingsPath'])) {
    if ($null -ne $global:PSProfileConfig.Settings -and $null -ne $global:PSProfileConfig.Settings.Keys) {
        if ($logOutput) {
            &$log "Creating settings.json @ $($global:PSProfileConfig._internal['ProfileSettingsPath'])" "Profile" "Maint"
        }
        $global:PSProfileConfig.Settings | ConvertTo-Json -Depth 5 | Set-Content $global:PSProfileConfig._internal['ProfileSettingsPath'] -Force
    }
}
else {
    if ($logOutput) {
        &$log "Importing settings.json @ $($global:PSProfileConfig._internal['ProfileSettingsPath'])" "Profile" "Maint"
    }
    if ($null -eq $global:PSProfileConfig.Settings) {
        $global:PSProfileConfig.Settings = @{}
    }
    $private:_settings = Get-Content $global:PSProfileConfig._internal['ProfileSettingsPath'] -Raw | ConvertFrom-Json
    foreach ($prop in $private:_settings.PSObject.Properties.Name) {
        $global:PSProfileConfig.Settings[$prop] = $private:_settings.$prop
    }
}
#endregion: Manage local settings file for settings persistence between sessions

#region: Invoke additional profile scripts
$global:PSProfileConfig._internal['ProfileFiles'] = Get-ChildItem $PSScriptRoot -Include "*.ps1" -Recurse | Where-Object {
    $_.Name -notmatch '^(WIP|profile.ps1|CONFIG)'
}
foreach ($file in $global:PSProfileConfig._internal['ProfileFiles']) {
    if ($logOutput) {
        &$log ". '$($file.FullName.Replace($PSScriptRoot,'.'))'" "Script" "Invoke"
    }
    Invoke-Expression ([System.IO.File]::ReadAllText($file.FullName))
}
#endregion: Invoke additional profile scripts

#region: Set prompt
if (-not $env:DemoInProgress) {
    $global:PSProfileConfig.ModulesToImport | ForEach-Object {
        if ($logOutput) {
            &$log $_ "Module" "Import"
        }
        Import-Module $_ -ErrorAction SilentlyContinue
    }
    if ($global:PSProfileConfig.Settings.Prompt) {
        if ($logOutput) {
            &$log "Setting prompt to $($global:PSProfileConfig.Settings.Prompt)" "Profile" "Maint"
        }
        Switch-Prompt -Prompt $global:PSProfileConfig.Settings.Prompt
    }
}
else {
    demo
}
#endregion: Set prompt

$Global:Error.Clear()

Write-Host ("Loading personal profile alone took {0}ms." -f ([Math]::Round(((Get-Date) - $global:PSProfileConfig._internal.ProfileLoadStart).TotalMilliseconds,0)))
