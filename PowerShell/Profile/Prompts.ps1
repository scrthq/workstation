function global:Get-Prompt {
    $i = 0
    $leadingWhiteSpace = $null
    "function global:prompt {`n" + $((Get-Command prompt).Definition -split "`n" | ForEach-Object {
            if (-not [String]::IsNullOrWhiteSpace($_)) {
                if ($null -eq $leadingWhiteSpace) {
                    $leadingWhiteSpace = ($_ | Select-String -Pattern '^\s+').Matches[0].Value
                }
                $_ -replace "^$leadingWhiteSpace",'    '
                "`n"
            }
            elseif ($i) {
                $_
                "`n"
            }
            $i++
        }) + "}"
}

function global:Get-PSVersion {
    [OutputType('System.String')]
    [CmdletBinding()]
    Param (
        [parameter(Position = 0)]
        [AllowNull()]
        [int]
        $Places
    )
    Process {
        $version = $PSVersionTable.PSVersion.ToString()
        if ($PSBoundParameters.ContainsKey('Places') -and $null -ne $Places) {
            $split = ($version -split '\.')[0..($Places - 1)]
            if ("$($split[-1])".Length -gt 1) {
                $split[-1] = "$($split[-1])".Substring(0,1)
            }
            $joined = $split -join '.'
            if ($version -match '[a-zA-Z]+') {
                $joined += "-$(($Matches[0]).Substring(0,1))"
                if ($version -match '\d+$') {
                    $joined += $Matches[0]
                }
            }
            $joined
        }
        else {
            $version
        }
    }
}

function global:Test-IfGit {
    [CmdletBinding()]
    Param ()
    Process {
        try {
            $topLevel = git rev-parse --show-toplevel *>&1
            if ($topLevel -like 'fatal: *') {
                $false
            }
            else {
                $origin = git remote get-url origin
                $repo = Split-Path -Leaf $origin
                [PSCustomObject]@{
                    TopLevel = (Resolve-Path $topLevel).Path
                    Origin   = $origin
                    Repo     = $(if ($repo -notmatch '(\.git|\.ssh|\.tfs)$') {$repo} else {$repo.Substring(0,($repo.LastIndexOf('.')))})
                }
            }
        }
        catch {
            $false
        }
    }
}

function global:Get-PathAlias {
    [CmdletBinding()]
    Param (
        [parameter(Position = 0)]
        [string]
        $Path = $PWD.Path,
        [parameter(Position = 1)]
        [string]
        $DirectorySeparator = $global:PathAliasDirectorySeparator
    )
    Begin {
        try {
            $origPath = $Path
            if ($null -eq $global:PSProfileConfig) {
                $global:PSProfileConfig = @{
                    _internal = @{
                        PathAliasMap = @{
                            '~' = $env:USERPROFILE
                        }
                    }
                }
            }
            elseif ($null -eq $global:PSProfileConfig['_internal']) {
                $global:PSProfileConfig['_internal'] = @{
                    PathAliasMap = @{
                        '~' = $env:USERPROFILE
                    }
                }
            }
            elseif ($null -eq $global:PSProfileConfig['_internal']['PathAliasMap']) {
                $global:PSProfileConfig['_internal']['PathAliasMap'] = @{
                    '~' = $env:USERPROFILE
                }
            }
            if ($gitRepo = Test-IfGit) {
                $gitIcon = [char]0xe0a0
                $key = $gitIcon + $gitRepo.Repo
                if (-not $global:PSProfileConfig['_internal']['PathAliasMap'].ContainsKey($key)) {
                    $global:PSProfileConfig['_internal']['PathAliasMap'][$key] = $gitRepo.TopLevel
                }
            }
            $leaf = Split-Path $Path -Leaf
            if (-not $global:PSProfileConfig['_internal']['PathAliasMap'].ContainsKey('~')) {
                $global:PSProfileConfig['_internal']['PathAliasMap']['~'] = $env:USERPROFILE
            }
            Write-Verbose "Alias map => JSON: $($global:PSProfileConfig['_internal']['PathAliasMap'] | ConvertTo-Json -Depth 5)"
            $aliasKey = $null
            $aliasValue = $null
            foreach ($hash in $global:PSProfileConfig['_internal']['PathAliasMap'].GetEnumerator() | Sort-Object {$_.Value.Length} -Descending) {
                if ($Path -like "$($hash.Value)*") {
                    $Path = $Path.Replace($hash.Value,$hash.Key)
                    $aliasKey = $hash.Key
                    $aliasValue = $hash.Value
                    Write-Verbose "AliasKey [$aliasKey] || AliasValue [$aliasValue]"
                    break
                }
            }
        }
        catch {
            Write-Error $_
            return $origPath
        }
    }
    Process {
        try {
            if ($null -ne $aliasKey -and $origPath -eq $aliasValue) {
                Write-Verbose "Matched original path! Returning alias base path"
                $finalPath = $Path
            }
            elseif ($null -ne $aliasKey) {
                Write-Verbose "Matched alias key [$aliasKey]! Returning path alias with leaf"
                $drive = "$($aliasKey)\"
                $finalPath = if ((Split-Path $origPath -Parent) -eq $aliasValue) {
                    "$($drive)$($leaf)"
                }
                else {
                    "$($drive)$([char]0x2026)\$($leaf)"
                }
            }
            else {
                $drive = (Get-Location).Drive.Name + ':\'
                Write-Verbose "Matched base drive [$drive]! Returning base path"
                $finalPath = if ($Path -eq $drive) {
                    $drive
                }
                elseif ((Split-Path $Path -Parent) -eq $drive) {
                    "$($drive)$($leaf)"
                }
                else {
                    "$($drive)..\$($leaf)"
                }
            }
            if ($DirectorySeparator -notin @($null,([System.IO.Path]::DirectorySeparatorChar))) {
                $finalPath.Replace(([System.IO.Path]::DirectorySeparatorChar),$DirectorySeparator)
            }
            else {
                $finalPath
            }
        }
        catch {
            Write-Error $_
            return $origPath
        }
    }
}

function global:Get-Elapsed {
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]
        $Id,
        [Parameter()]
        [string]
        $Format = "{0:h\:mm\:ss\.ffff}"
    )
    $null = $PSBoundParameters.Remove("Format")
    $LastCommand = Get-History -Count 1 @PSBoundParameters
    if (!$LastCommand) {
        return "0:00:00.0000"
    }
    elseif ($null -ne $LastCommand.Duration) {
        $Format -f $LastCommand.Duration
    }
    else {
        $Duration = $LastCommand.EndExecutionTime - $LastCommand.StartExecutionTime
        $Format -f $Duration
    }
}

function global:Switch-Prompt {
    [CmdletBinding()]
    Param (
        [parameter(Position = 0,ValueFromPipeline)]
        [ValidateSet('Basic','BasicPlus','Original','Clean','Fast','Demo','Slim','Rayner','Full','PowerLine')]
        [String]
        $Prompt = 'Basic',
        [parameter()]
        [Alias('ng')]
        [switch]
        $NoGit,
        [parameter()]
        [Alias('nc')]
        [switch]
        $NoClear
    )
    Begin {
        if (-not $NoClear) {
            if (-not (Test-Path Env:\PSProfileClear) -or (($env:PSProfileClear -as [int]) -as [bool])) {
                Clear-Host
            }
        }
        if (-not $PSBoundParameters.ContainsKey('Prompt') -and $MyInvocation.InvocationName -in @('Set-DemoPrompt','Start-Demo','demo')) {
            $Prompt = 'Demo'
            $NoGit = $true
        }
        if ($Prompt -eq 'Fast') {
            $Prompt = 'Slim'
            $NoGit = $true
        }
        elseif ($Prompt -in @('Clean','Basic')) {
            $NoGit = $true
        }
        elseif ($Prompt -in @('Full','PowerLine')) {
            Import-Module PowerLine
            Set-PowerLinePrompt -PowerLineFont -Verbose:$false
        }
        if (-not $NoGit) {
            Import-Module posh-git -Verbose:$false
            $GitPromptSettings.EnableWindowTitle = "Repo Info:  "
        }
        $global:PreviousPrompt = if ($global:CurrentPrompt) {
            $global:CurrentPrompt
        }
        else {
            $null
        }
        $global:CurrentPrompt = $Prompt
        $global:_useGit = -not $NoGit
    }
    Process {
        if ($Prompt) {
            Write-Verbose "Setting prompt to [$Prompt]"
            switch ($Prompt) {
                Slim {
                    <# Appearance:
                    [#12] [0:00:00.0347] ~\Personal-Settings [master ≡ +3 ~3 -1 !]
                    [PS 6.2]>
                    #>
                    function global:prompt {
                        $lastStatus = $?
                        $lastColor = if ($lastStatus -eq $true) {
                            'Green'
                        }
                        else {
                            "Red"
                        }
                        Write-Host "[" -NoNewline
                        Write-Host -ForegroundColor Cyan "#$($MyInvocation.HistoryId)" -NoNewline
                        Write-Host "] " -NoNewline
                        Write-Host "[" -NoNewline
                        Write-Host -ForegroundColor $lastColor ("{0}" -f (Get-Elapsed)) -NoNewline
                        Write-Host "] [" -NoNewline
                        Write-Host ("{0}" -f $(Get-PathAlias)) -NoNewline -ForegroundColor DarkYellow
                        Write-Host "]" -NoNewline
                        if ($PWD.Path -notlike "G:\GDrive\GoogleApps*" -and $env:DisablePoshGit -ne $true -and $global:_useGit -and (git config -l --local *>&1) -notmatch '^fatal') {
                            Write-VcsStatus
                        }
                        Write-Host "`n[" -NoNewLine
                        $verColor = @{
                            ForegroundColor = if ($PSVersionTable.PSVersion.Major -eq 7) {
                                'Yellow'
                            }
                            elseif ($PSVersionTable.PSVersion.Major -eq 6) {
                                'Magenta'
                            }
                            else {
                                'Cyan'
                            }
                        }
                        Write-Host @verColor ("PS {0}" -f (Get-PSVersion $global:PSProfileConfig.Settings.PSVersionStringLength)) -NoNewline
                        Write-Host "]" -NoNewLine
                        $('>' * ($nestedPromptLevel + 1) + ' ')
                    }
                }
                Clean {
                    $global:CleanNumber = 0
                    function global:prompt {
                        $global:CleanNumber++
                        -join @(
                            '[CLN#'
                            $global:CleanNumber
                            '] ['
                            [Math]::Round((Get-History -Count 1).Duration.TotalMilliseconds,0)
                            'ms] '
                            $(Get-PathAlias)
                            ("`n[PS {0}" -f (Get-PSVersion $global:PSProfileConfig.Settings.PSVersionStringLength))
                            ']>> '
                        )
                    }
                }
                Basic {
                    function global:prompt {
                        "PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) ";
                        # .Link
                        # https://go.microsoft.com/fwlink/?LinkID=225750
                        # .ExternalHelp System.Management.Automation.dll-help.xml
                    }
                }
                BasicPlus {
                    function global:prompt {
                        -join @(
                            '<# PS {0} | ' -f (Get-PSVersion $global:PSProfileConfig.Settings.PSVersionStringLength)
                            Get-PathAlias
                            ' #> '
                        )
                    }
                }
                Original {
                    function global:prompt {
                        $ra = [char]0xe0b0
                        $fg = @{
                            ForegroundColor = $Host.UI.RawUI.BackgroundColor
                        }
                        $cons = if ($psEditor) {
                            'Code'
                        }
                        elseif ($env:ConEmuPID) {
                            'ConEmu'
                        }
                        else {
                            'PS'
                        }
                        switch ($PSVersionTable.PSVersion.Major) {
                            5 {
                                $idColor = 'Green'
                                $verColor = 'Cyan'
                            }
                            6 {
                                $idColor = 'Cyan'
                                $verColor = 'Green'
                            }
                            7 {
                                $idColor = 'Cyan'
                                $verColor = 'Yellow'
                            }
                        }
                        Write-Host @fg -BackgroundColor $idColor "$ra[$($MyInvocation.HistoryId)]" -NoNewline
                        Write-Host -ForegroundColor $idColor $ra -NoNewline
                        Write-Host @fg -BackgroundColor $verColor "$ra[$("PS {0}" -f (Get-PSVersion $global:PSProfileConfig.Settings.PSVersionStringLength))]" -NoNewline
                        Write-Host -ForegroundColor $verColor $ra -NoNewline
                        if ($global:_useGit -and $PWD.Path -notlike "G:\GDrive\GoogleApps*" -and (git config -l --local *>&1) -notmatch '^fatal') {
                            Write-Host @fg -BackgroundColor Yellow "$ra[$(Get-Elapsed) @ $(Get-Date -Format T)]" -NoNewline
                            Write-Host -ForegroundColor Yellow $ra -NoNewline
                            Write-VcsStatus
                            Write-Host ""
                        }
                        else {
                            Write-Host @fg -BackgroundColor Yellow "$ra[$(Get-Elapsed) @ $(Get-Date -Format T)]" -NoNewline
                            Write-Host -ForegroundColor Yellow $ra
                        }
                        Write-Host @fg -BackgroundColor Magenta "$ra[$(Get-PathAlias)]" -NoNewline
                        Write-Host -ForegroundColor Magenta $ra -NoNewline
                        Write-Host "`n[I " -NoNewline
                        Write-Host -ForegroundColor Red "$([char]9829)" -NoNewline
                        " $cons]$('>' * ($nestedPromptLevel + 1)) "
                    }
                }
                Rayner {
                    <# Adapted from @thomasrayner's dev-workstation prompt:
                    https://github.com/thomasrayner/dev-workstation/blob/master/prompt.ps1
                    #>
                    <# Appearance (looks better in full color):
                    0004»1CPSGSuitemaster                                                0:00:00.018210:52:23 PM
                    PS 6.2>
                    #>
                    $forePromptColor = 0

                    [System.Collections.Generic.List[ScriptBlock]]$global:PromptRight = @(
                        # right aligned
                        { "$foreground;${errorStatus}m{0}" -f $lArrow }
                        { "$foreground;${forePromptColor}m$background;${errorStatus}m{0}" -f $(Get-Elapsed) }
                        { "$foreground;7m$background;${errorStatus}m{0}" -f $lArrow }
                        { "$foreground;0m$background;7m{0}" -f $(get-date -format "hh:mm:ss tt") }
                    )

                    [System.Collections.Generic.List[ScriptBlock]]$global:PromptLeft = @(
                        # left aligned
                        { "$foreground;${forePromptColor}m$background;${global:platform}m{0}" -f $('{0:d4}' -f $MyInvocation.HistoryId) }
                        { "$background;22m$foreground;${global:platform}m{0}" -f $($rArrow) }
                        { "$background;22m$foreground;${forePromptColor}m{0}" -f $(if ($pushd = (Get-Location -Stack).count) {
                                    "$([char]187)" + $pushd
                                }) }
                        { "$foreground;22m$background;5m{0}" -f $rArrow }
                        { "$background;5m$foreground;${forePromptColor}m{0}" -f $($pwd.Drive.Name) }
                        { "$background;14m$foreground;5m{0}" -f $rArrow }
                        { "$background;14m$foreground;${forePromptColor}m{0}$escape[0m" -f $(Split-Path $pwd -leaf) }
                    )
                    function global:prompt {
                        $global:errorStatus = if ($?) {
                            22
                        }
                        else {
                            1
                        }
                        $global:platform = if ($isWindows) {
                            11
                        }
                        else {
                            117
                        }
                        $global:lArrow = [char]0xe0b2
                        $global:rArrow = [char]0xe0b0
                        $escape = "$([char]27)"
                        $foreground = "$escape[38;5"
                        $background = "$escape[48;5"
                        $prompt = ''

                        $gitTest = $global:_useGit -and $PWD.Path -notlike "G:\GDrive\GoogleApps*" -and (git config -l --local *>&1) -notmatch '^fatal'
                        if ($gitTest) {
                            $branch = git symbolic-ref --short -q HEAD
                            $aheadbehind = git status -sb
                            $distance = ''
                            if (-not [string]::IsNullOrEmpty($(git diff --staged))) {
                                $branchbg = 3
                            }
                            else {
                                $branchbg = 5
                            }
                            if (-not [string]::IsNullOrEmpty($(git status -s))) {
                                $arrowfg = 3
                            }
                            else {
                                $arrowfg = 5
                            }
                            if ($aheadbehind -match '\[\w+.*\w+\]$') {
                                $ahead = [regex]::matches($aheadbehind, '(?<=ahead\s)\d+').value
                                $behind = [regex]::matches($aheadbehind, '(?<=behind\s)\d+').value
                                $distance = "$background;15m$foreground;${arrowfg}m{0}$escape[0m" -f $rArrow
                                if ($ahead) {
                                    $distance += "$background;15m$foreground;${forePromptColor}m{0}$escape[0m" -f "a$ahead"
                                }
                                if ($behind) {
                                    $distance += "$background;15m$foreground;${forePromptColor}m{0}$escape[0m" -f "b$behind"
                                }
                                $distance += "$foreground;15m{0}$escape[0m" -f $rArrow
                            }
                            else {
                                $distance = "$foreground;${arrowfg}m{0}$escape[0m" -f $rArrow
                            }
                            [System.Collections.Generic.List[ScriptBlock]]$gitPrompt = @(
                                { "$background;${branchbg}m$foreground;14m{0}$escape[0m" -f $rArrow }
                                { "$background;${branchbg}m$foreground;${forePromptColor}m{0}$escape[0m" -f $branch }
                                { "{0}$escape[0m" -f $distance }
                            )
                            $prompt = -join @($global:PromptLeft + $gitPrompt + { " " }).Invoke()
                        }
                        else {
                            $prompt = -join @($global:PromptLeft + { "$foreground;14m{0}$escape[0m" -f $rArrow } + { " " }).Invoke()
                        }
                        $rightPromptString = -join ($global:promptRight).Invoke()
                        $offset = $global:host.UI.RawUI.BufferSize.Width - 24
                        $returnedPrompt = -join @($prompt, "$escape[${offset}G", $rightPromptString, "$escape[0m" + ("`n`r`PS {0}.{1}> " -f $PSVersionTable.PSVersion.Major,$PSVersionTable.PSVersion.Minor))
                        $returnedPrompt
                    }
                }
                Demo {
                    <# Appearance:
                    CMD# [2] | Dir: [~\Personal-Settings] | Last: [0:00:00.0087] | Git: [master ≡ +3 ~3 -1 !]
                    PS [6.2]>
                    #>
                    function global:prompt {
                        $lastStatus = $?
                        Write-Host "CMD# " -NoNewline
                        Write-Host -ForegroundColor Green "[$($MyInvocation.HistoryId)] " -NoNewline
                        #Write-Host -ForegroundColor Cyan "[$((Get-Location).Path.Replace($env:HOME,'~'))] " -NoNewline
                        $lastColor = if ($lastStatus -eq $true) {
                            "Yellow"
                        }
                        else {
                            "Red"
                        }
                        Write-Host "| Dir: " -NoNewLine
                        Write-Host -ForegroundColor Cyan "[$(Get-PathAlias)] " -NoNewline
                        Write-Host "| Last: " -NoNewLine
                        Write-Host -ForegroundColor $lastColor "[$(Get-Elapsed)] " -NoNewline
                        if ($global:_useGit -and $PWD.Path -notlike "G:\GDrive\GoogleApps*" -and (git config -l --local *>&1) -notmatch '^fatal') {
                            Write-Host "| Git:" -NoNewLine
                            Write-VcsStatus
                        }
                        Write-Host "`nPS " -NoNewline
                        $verColor = if ($PSVersionTable.PSVersion.Major -lt 6) {
                            @{
                                ForegroundColor = 'Cyan'
                                BackgroundColor = $host.UI.RawUI.BackgroundColor
                            }
                        }
                        elseif ($PSVersionTable.PSVersion.Major -eq 6) {
                            @{
                                ForegroundColor = $host.UI.RawUI.BackgroundColor
                                BackgroundColor = 'Cyan'
                            }
                        }
                        elseif ($PSVersionTable.PSVersion.Major -eq 7) {
                            @{
                                ForegroundColor = $host.UI.RawUI.BackgroundColor
                                BackgroundColor = 'Yellow'
                            }
                        }
                        Write-Host @verColor ("[{0}]" -f (Get-PSVersion $global:PSProfileConfig.Settings.PSVersionStringLength)) -NoNewline
                        ('>' * ($nestedPromptLevel + 1)) + ' '
                    }
                }
                PowerLine {
                    Set-PowerLinePrompt -PowerLineFont -SetCurrentDirectory -RestoreVirtualTerminal -Newline -Timestamp -Colors ([PoshCode.Pansies.RgbColor]::ConsolePalette)
                    Add-PowerLineBlock { if ($pushed = (Get-Location -Stack).count) {
                            "&raquo;$pushed"
                        } }  -Index 1
                    Add-PowerLineBlock { Write-VcsStatus }  -Index 3
                }
                Full {
                    if ( -not $env:ConEmuPID ) {
                        function global:prompt {
                            $E = "$([char]27)"
                            $F = "$E[38;5"
                            $B = "$E[48;5"
                            "$B;255m$F;0mI $F;1m$([char]9829) $F;0mPS $F;0m$B;255m$([char]8250)$E[0m "
                        }
                    }
                    else {
                        [ScriptBlock[]]$global:Prompt = @(
                            # right aligned
                            { " " * ($Host.UI.RawUI.BufferSize.Width - 29) }
                            { "$F;${er}m{0}" -f [char]0xe0b2 }
                            { "$F;15m$B;${er}m{0}" -f $(if (@(get-history).Count -gt 0) {
                                        (get-history)[-1] | ForEach-Object { "{0:c}" -f (new-timespan $_.StartExecutionTime $_.EndExecutionTime) }
                                    }
                                    else {
                                        '00:00:00.0000000'
                                    }) }

                            { "$F;7m$B;${er}m{0}" -f [char]0xe0b2 }
                            { "$F;0m$B;7m{0}" -f $(get-date -format "hh:mm:ss tt") }


                            # left aligned
                            { "$F;15m$B;117m{0}" -f $('{0:d4}' -f $MyInvocation.HistoryId) }
                            { "$B;22m$F;117m{0}" -f $([char]0xe0b0) }

                            { "$B;22m$F;15m{0}" -f $(if ($pushd = (Get-Location -Stack).count) {
                                        "$([char]187)" + $pushd
                                    }) }
                            { "$F;22m$B;5m{0}" -f $([char]0xe0b0) }

                            { "$B;5m$F;15m{0}" -f $($pwd.Drive.Name) }
                            { "$B;20m$F;5m{0}" -f $([char]0xe0b0) }

                            { "$B;20m$F;15m{0}$E[0m" -f $(Split-Path $pwd -leaf) }
                            { "$F;20m{0}$E[0m" -f $([char]0xe0b0) }
                        )
                        function global:prompt {
                            $global:er = if ($?) {
                                22
                            }
                            else {
                                1
                            }
                            $E = "$([char]27)"
                            $F = "$E[38;5"
                            $B = "$E[48;5"
                            -join $global:Prompt.Invoke()
                        }
                    }
                }
            }
        }
    }
}

Set-Alias -Name sprompt -Value Switch-Prompt -Option AllScope -Force
Set-Alias -Name pro -Value Switch-Prompt -Option AllScope -Force
