if ($PSVersionTable.PSVersion.Major -lt 6 -or $IsWindows) {
    $env:PYTHONIOENCODING = "UTF-8"
}

function Convert-Duration {
    <#
    .SYNOPSIS
    Converts a TimeSpan or ISO8601 duration string to the desired output type.

    .DESCRIPTION
    Converts a TimeSpan or ISO8601 duration string to the desired output type.

    More info on ISO8601 duration strings: https://en.wikipedia.org/wiki/ISO_8601#Durations

    .PARAMETER Duration
    The TimeSpan object or ISO8601 string to convert.

    .PARAMETER Output
    The desired Output type.

    Defaults to TimeSpan.

    .EXAMPLE
    Convert-Duration 'PT1H32M15S'

    Days              : 0
    Hours             : 1
    Minutes           : 32
    Seconds           : 15
    Milliseconds      : 0
    Ticks             : 55350000000
    TotalDays         : 0.0640625
    TotalHours        : 1.5375
    TotalMinutes      : 92.25
    TotalSeconds      : 5535
    TotalMilliseconds : 5535000

    .EXAMPLE
    Start-Sleep -Seconds (Convert-Duration 'PT5M35S' -Output TotalSeconds)

    # Sleeps for 5 minutes and 35 seconds

    .EXAMPLE
    $date = Get-Date
    $duration = $date.AddMinutes(37) - $date
    Convert-Duration $duration -Output ISO8601

    PT37M
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory,ValueFromPipeline,Position = 0)]
        [ValidateScript({
            if ($_.GetType().Name -eq 'TimeSpan' -or $_ -match '^P((?<Years>[\d\.,]+)Y)?((?<Months>[\d\.,]+)M)?((?<Weeks>[\d\.,]+)W)?((?<Days>[\d\.,]+)D)?(?<Time>T((?<Hours>[\d\.,]+)H)?((?<Minutes>[\d\.,]+)M)?((?<Seconds>[\d\.,]+)S)?)?$') {
                $true
            }
            else {
                throw "Input object must be a valid ISO8601 format string or a TimeSpan object."
            }
        })]
        [Object]
        $Duration,
        [Parameter(Position = 1)]
        [ValidateSet('TimeSpan','ISO8601','Hashtable','TotalSeconds')]
        [String]
        $Output = 'TimeSpan'
    )
    Begin {
        $validKeys = @('Years','Months','Weeks','Days','Hours','Minutes','Seconds')
    }
    Process {
        switch ($Duration.GetType().Name) {
            String {
                if ($Duration -match '^P((?<Years>[\d\.,]+)Y)?((?<Months>[\d\.,]+)M)?((?<Weeks>[\d\.,]+)W)?((?<Days>[\d\.,]+)D)?(?<Time>T((?<Hours>[\d\.,]+)H)?((?<Minutes>[\d\.,]+)M)?((?<Seconds>[\d\.,]+)S)?)?$') {
                    if ($Output -eq 'ISO8601') {
                        $Duration
                    }
                    else {
                        $final = @{}
                        $d = Get-Date
                        switch ($Output) {
                            TotalSeconds {
                                $seconds = 0
                                foreach ($key in $Matches.Keys | Where-Object {$_ -in $validKeys}) {
                                    Write-Verbose "Matched key '$key' with value '$($Matches[$key])'"
                                    $multiplier = switch ($key) {
                                        Years {
                                            ($d.AddYears(1) - $d).TotalSeconds
                                        }
                                        Months {
                                            ($d.AddMonths(1) - $d).TotalSeconds
                                        }
                                        Weeks {
                                            ($d.AddDays(7) - $d).TotalSeconds
                                        }
                                        Days {
                                            ($d.AddDays(1) - $d).TotalSeconds
                                        }
                                        Hours {
                                            3600
                                        }
                                        Minutes {
                                            60
                                        }
                                        Seconds {
                                            1
                                        }
                                    }
                                    $seconds += ($multiplier * [int]($Matches[$key]))
                                }
                                $seconds
                            }
                            TimeSpan {
                                foreach ($key in $Matches.Keys | Where-Object {$_ -in $validKeys}) {
                                    Write-Verbose "Matched key '$key' with value '$($Matches[$key])'"
                                    if (-not $final.ContainsKey('Days')) {
                                        $final['Days'] = 0
                                    }
                                    switch ($key) {
                                        Years {
                                            $final['Days'] += (($d.AddYears(1) - $d).TotalDays * [int]($Matches[$key]))
                                        }
                                        Months {
                                            $final['Days'] += (($d.AddMonths(1) - $d).TotalDays * [int]($Matches[$key]))
                                        }
                                        Weeks {
                                            $final['Days'] += (7 * [int]($Matches[$key]))
                                        }
                                        Days {
                                            $final['Days'] += [int]($Matches[$key])
                                        }
                                        default {
                                            $final[$key] = [int]($Matches[$key])
                                        }
                                    }
                                    $final['Seconds'] += ($multiplier * [int]($Matches[$key]))
                                }
                                New-TimeSpan @final
                            }
                            Hashtable {
                                foreach ($key in $Matches.Keys | Where-Object {$_ -in $validKeys}) {
                                    Write-Verbose "Matched key '$key' with value '$($Matches[$key])'"
                                    $final[$key] = [int]($Matches[$key])
                                }
                                $final
                            }
                        }
                    }
                }
                else {
                    Write-Error "Input string was not a valid ISO8601 format! Please reference the Duration section on the Wikipedia page for ISO8601 for syntax: https://en.wikipedia.org/wiki/ISO_8601#Durations"
                }
            }
            TimeSpan {
                if ($Output -eq 'TimeSpan') {
                    $Duration
                }
                else {
                    $final = @{}
                    $d = Get-Date
                    switch ($Output) {
                        TotalSeconds {
                            $Duration.TotalSeconds
                        }
                        Hashtable {
                            foreach ($key in $validKeys) {
                                if ($Duration.$key) {
                                    $final[$key] = $Duration.$key
                                }
                            }
                            $final
                        }
                        ISO8601 {
                            $pt = 'P'
                            if ($Duration.Days) {
                                $pt += ("{0}D" -f $Duration.Days)
                            }
                            if ($Duration.Hours + $Duration.Minutes + $Duration.Seconds) {
                                $pt += 'T'
                                if ($Duration.Hours) {
                                    $pt += ("{0}H" -f $Duration.Hours)
                                }
                                if ($Duration.Minutes) {
                                    $pt += ("{0}M" -f $Duration.Minutes)
                                }
                                if ($Duration.Seconds) {
                                    $pt += ("{0}S" -f $Duration.Seconds)
                                }
                            }
                            $pt
                        }
                    }
                }
            }
        }
    }
}

function Get-PublicIp {
    [CmdletBinding()]
    Param (
        [parameter(Position = 0,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [Alias('Name','PSComputerName','HostName','Host','Computer')]
        [string[]]
        $ComputerName = @($env:COMPUTERNAME)
    )
    Begin {
        $ScriptBlock = {
            [PSCustomObject]@{
                ComputerName = $env:COMPUTERNAME
                PublicIp     = (Invoke-RestMethod 'https://api.ipify.org?format=json').Ip
            }
        }
    }
    Process {
        if ($ComputerName -contains $env:COMPUTERNAME) {
            $ScriptBlock.Invoke()
        }
        if ($others = $ComputerName | Where-Object {$_ -ne $env:COMPUTERNAME}) {
            Invoke-Command -ComputerName $others -ScriptBlock $ScriptBlock | Select-Object ComputerName,PublicIp
        }
    }
}

function global:Get-Gist {
    [CmdletBinding()]
    Param (
        [parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName,Position = 0)]
        [String]
        $Id,
        [parameter(ValueFromPipelineByPropertyName)]
        [Alias('Files')]
        [String[]]
        $File,
        [parameter(ValueFromPipelineByPropertyName)]
        [String]
        $Sha,
        [parameter(ValueFromPipelineByPropertyName,ValueFromRemainingArguments)]
        [Object]
        $Metadata,
        [parameter()]
        [Switch]
        $Invoke
    )
    Process {
        $Uri = [System.Collections.Generic.List[string]]@(
            'https://api.github.com'
            '/gists/'
            $PSBoundParameters['Id']
        )
        if ($PSBoundParameters.ContainsKey('Sha')) {
            $Uri.Add("/$($PSBoundParameters['Sha'])")
            Write-Verbose "[$($PSBoundParameters['Id'])] Getting gist info @ SHA '$($PSBoundParameters['Sha'])'"
        }
        else {
            Write-Verbose "[$($PSBoundParameters['Id'])] Getting gist info"
        }
        $gistInfo = Invoke-RestMethod -Uri ([Uri](-join $Uri)) -Verbose:$false
        $fileNames = if ($PSBoundParameters.ContainsKey('File')) {
            $PSBoundParameters['File']
        }
        else {
            $gistInfo.files.PSObject.Properties.Name
        }
        foreach ($fileName in $fileNames) {
            Write-Verbose "[$fileName] Getting gist file content"
            $fileInfo = $gistInfo.files.$fileName
            $content = if ($fileInfo.truncated) {
                (Invoke-WebRequest -Uri ([Uri]$fileInfo.raw_url)).Content
            }
            else {
                $fileInfo.content
            }
            $lines = ($content -split "`n").Count
            if ($Invoke) {
                Write-Verbose "[$fileName] Parsing gist file content ($lines lines)"
                $noScopePattern = '^function\s+(?<Name>[\w+_-]{1,})\s+\{'
                $globalScopePattern = '^function\s+global\:'
                $noScope = [RegEx]::Matches($content, $noScopePattern, "Multiline, IgnoreCase")
                $globalScope = [RegEx]::Matches($content,$globalScopePattern,"Multiline, IgnoreCase")
                if ($noScope.Count -ge $globalScope.Count) {
                    foreach ($match in $noScope) {
                        $fullValue = ($match.Groups | Where-Object { $_.Name -eq 0 }).Value
                        $funcName = ($match.Groups | Where-Object { $_.Name -eq 'Name' }).Value
                        Write-Verbose "[$fileName::$funcName] Updating function to global scope to ensure it imports correctly."
                        $content = $content.Replace($fullValue, "function global:$funcName {")
                    }
                }
                Write-Verbose "[$fileName] Invoking gist file content"
                $ExecutionContext.InvokeCommand.InvokeScript(
                    $false,
                    ([scriptblock]::Create($content)),
                    $null,
                    $null
                )
            }
            [PSCustomObject]@{
                File    = $fileName
                Sha     = $Sha
                Count   = $lines
                Content = $content -join "`n"
            }
        }
    }
}

function global:Import-Splat {
    [CmdletBinding()]
    Param ()
    if ($null -eq (Get-Module EditorServicesCommandSuite* -ListAvailable)) {
        $installModuleSplat = @{
            Name               = 'EditorServicesCommandSuite'
            Repository         = 'PSGallery'
            AllowClobber       = $true
            Scope              = 'CurrentUser'
            SkipPublisherCheck = $true
        }
        Install-Module @installModuleSplat
    }
    if ($psEditor) {
        Import-Module EditorServicesCommandSuite -ErrorAction SilentlyContinue -Force
        Import-EditorCommand -Module EditorServicesCommandSuite
    }
}

Import-Splat

function global:Set-ProcessPriority {
    [CmdletBinding()]
    Param ()
    DynamicParam {
        $RuntimeParamDic = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        $AttribColl = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParamAttrib = New-Object System.Management.Automation.ParameterAttribute
        $ParamAttrib.Mandatory = $true
        $ParamAttrib.Position = 0
        $ParamAttrib.ValueFromPipeline = $true
        $AttribColl.Add($ParamAttrib)
        $set = (Get-CimInstance Win32_Process).Name | Sort-Object -Unique
        $AttribColl.Add((New-Object System.Management.Automation.ValidateSetAttribute($set)))
        $AttribColl.Add((New-Object System.Management.Automation.AliasAttribute('Name')))
        $RuntimeParam = New-Object System.Management.Automation.RuntimeDefinedParameter('Process',  [string[]], $AttribColl)
        $RuntimeParamDic.Add('Process',  $RuntimeParam)

        $AttribColl = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParamAttrib = New-Object System.Management.Automation.ParameterAttribute
        $ParamAttrib.Mandatory = $true
        $ParamAttrib.Position = 1
        $AttribColl.Add($ParamAttrib)
        $set = @('Realtime','High','AboveNormal','Normal','BelowNormal','Low')
        $AttribColl.Add((New-Object System.Management.Automation.ValidateSetAttribute($set)))
        $RuntimeParam = New-Object System.Management.Automation.RuntimeDefinedParameter('Priority',  [string], $AttribColl)
        $RuntimeParamDic.Add('Priority',  $RuntimeParam)

        return  $RuntimeParamDic
    }
    Begin {
        $priorityDict = @{
            Realtime    = 256
            High        = 128
            AboveNormal = 32768
            Normal      = 32
            BelowNormal = 16384
            Low         = 64
        }
    }
    Process {
        foreach ($procName in $PSBoundParameters['Process']) {
            Write-Verbose "Setting process '$procName' to priority '$($PSBoundParameters['Priority']) [$($priorityDict[$PSBoundParameters['Priority']])]'"
            $command = "Get-WmiObject Win32_Process | Where-Object {`$_.Name -eq '$($procName)'} | ForEach-Object {`$_.SetPriority($($priorityDict[$PSBoundParameters['Priority']]))} | Out-Null;Get-WmiObject Win32_Process | Where-Object {`$_.Name -eq '$($procName)'} | Format-Table Name,Path,Priority -AutoSize"
            if ($PSVersionTable.PSVersion.Major -le 5) {
                Write-Verbose "Invoking via { Invoke-Expression -Command `$command }"
                Invoke-Expression -Command $command
            }
            else {
                Write-Verbose "Invoking via { powershell -noprofile -command `$command }"
                powershell -noprofile -command "$command"
            }
        }
    }
}

function global:Update-GitAliases {
    [CmdletBinding()]
    Param()
    Process {
        if (Get-Command git) {
            $aliasList = @(
                "a = !git add . && git status"
                "aa = !git add . && git add -u . && git status"
                "ac = !git add . && git commit"
                "acm = !git add . && git commit -m"
                "alias = !git config --get-regexp '^alias\.' | sort"
                "amend = !git add -A && git commit --amend --no-edit"
                "au = !git add -u . && git status"
                "b = branch"
                "ba = branch --all"
                "c = commit"
                "ca = commit --amend # careful"
                "cam = commit -am"
                "cm = commit -m"
                "co = checkout"
                "con = !git --no-pager config --list"
                "conl = !git --no-pager config --local --list"
                "conls = !git --no-pager config --local --list --show-origin"
                "cons = !git --no-pager config --list --show-origin"
                "current = !git branch | grep \* | cut -d ' ' -f2"
                "d = !git --no-pager diff"
                "f = fetch --all"
                "fp = fetch --all --prune"
                "l = log --graph --all --pretty=format:'%C(yellow)%h%C(cyan)%d%Creset %s %C(white)- %an, %ar%Creset'"
                "lg = log --color --graph --pretty=format:'%C(bold white)%h%Creset -%C(bold green)%d%Creset %s %C(bold green)(%cr)%Creset %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative"
                "ll = log --stat --abbrev-commit"
                "llg = log --color --graph --pretty=format:'%C(bold white)%H %d%Creset%n%s%n%+b%C(bold blue)%an <%ae>%Creset %C(bold green)%cr (%ci)' --abbrev-commit"
                "master = checkout master"
                "n = checkout -b"
                "origin = remote get-url origin"
                "p = !git push"
                "pf = !git push -f"
                "pu = !git push -u origin ```$(git branch | grep \* | cut -d ' ' -f2)"
                "s = status"
                "ss = status -s"
            )
            Write-Verbose "Setting git aliases:"
            foreach ($alias in $aliasList) {
                $side = $alias -split " = "
                Write-Verbose "$($side[0]) = $($side[1])"
                Invoke-Expression $("git config --global alias.{0} `"{1}`"" -f $side[0],$side[1])
            }
        }
    }
}

function global:cln {
    [CmdletBinding()]
    Param (
        [parameter(Position = 0)]
        [ValidateSet('powershell','pwsh','pwsh-preview')]
        [Alias('E')]
        [String]
        $Engine = $(if ($PSVersionTable.PSVersion.Major -ge 6) {
                'pwsh'
            }
            else {
                'powershell'
            }),
        [Parameter()]
        [Alias('ipmo','Import')]
        [Switch]
        $ImportModule
    )
    Process {
        $verboseMessage = "Creating clean environment...`n           Engine : $Engine"
        $command = "$Engine -NoProfile -NoExit -C `"```$global:CleanNumber = 0;if (```$null -ne (Get-Module PSReadline)) {Set-PSReadLineKeyHandler -Chord Tab -Function MenuComplete;Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward;Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward;Set-PSReadLineKeyHandler -Chord 'Ctrl+W' -Function BackwardKillWord;Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function MenuComplete;Set-PSReadLineKeyHandler -Chord 'Ctrl+D' -Function KillWord;};function global:prompt {```$global:CleanNumber++;'[CLN#' + ```$global:CleanNumber + '] [' + [Math]::Round((Get-History -Count 1).Duration.TotalMilliseconds,0) + 'ms] ' + ```$((Get-Location).Path.Replace(```$env:Home,'~')) + '```n[PS ' + ```$PSVersionTable.PSVersion.ToString() + ']>> '};"
        if ($ImportModule) {
            if (($modName = (Get-ChildItem .\BuildOutput -Directory).BaseName)) {
                $modPath = '.\BuildOutput\' + $modName
                $verboseMessage += "`n           Module : $modName"
                $command += "Import-Module '$modPath' -Verbose:```$false;Get-Module $modName"
            }
        }
        $command += '"'
        Write-Verbose $verboseMessage
        Invoke-Expression $command
    }
}

function global:bld {
    [CmdletBinding(PositionalBinding = $false)]
    Param (
        [parameter()]
        [Alias('ne')]
        [Switch]
        $NoExit,
        [parameter()]
        [Alias('nr')]
        [Switch]
        $NoRestore
    )
    DynamicParam {
        $RuntimeParamDic = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $AttribColl = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParamAttrib = New-Object System.Management.Automation.ParameterAttribute
        $ParamAttrib.Mandatory = $false
        $ParamAttrib.Position = 0
        $AttribColl.Add($ParamAttrib)
        $set = @()
        $set += $global:PSProfileConfig['_internal']['PSBuildPathMap'].Keys
        $set += '.'
        $AttribColl.Add((New-Object System.Management.Automation.ValidateSetAttribute($set)))
        $AttribColl.Add((New-Object System.Management.Automation.AliasAttribute('p')))
        $RuntimeParam = New-Object System.Management.Automation.RuntimeDefinedParameter('Project',  [string], $AttribColl)
        $RuntimeParamDic.Add('Project',  $RuntimeParam)

        $AttribColl = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParamAttrib = New-Object System.Management.Automation.ParameterAttribute
        $ParamAttrib.Mandatory = $false
        $ParamAttrib.Position = 1
        $AttribColl.Add($ParamAttrib)
        $bldFile = Join-Path $PWD.Path "build.ps1"
        $set = if (Test-Path $bldFile) {
            ((([System.Management.Automation.Language.Parser]::ParseFile($bldFile, [ref]$null, [ref]$null)).ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Task' }).Attributes | Where-Object { $_.TypeName.Name -eq 'ValidateSet' }).PositionalArguments.Value
        }
        else {
            @('Update','Clean','Compile','CompileCSharp','Import','Test','TestOnly','Deploy')
        }
        $AttribColl.Add((New-Object System.Management.Automation.ValidateSetAttribute($set)))
        $AttribColl.Add((New-Object System.Management.Automation.AliasAttribute('t')))
        $RuntimeParam = New-Object System.Management.Automation.RuntimeDefinedParameter('Task',  [string[]], $AttribColl)
        $RuntimeParamDic.Add('Task',  $RuntimeParam)

        $AttribColl = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParamAttrib = New-Object System.Management.Automation.ParameterAttribute
        $ParamAttrib.Mandatory = $false
        $ParamAttrib.Position = 2
        $AttribColl.Add($ParamAttrib)
        $set = @('powershell','pwsh','pwsh-preview')
        $AttribColl.Add((New-Object System.Management.Automation.ValidateSetAttribute($set)))
        $AttribColl.Add((New-Object System.Management.Automation.AliasAttribute('e')))
        $RuntimeParam = New-Object System.Management.Automation.RuntimeDefinedParameter('Engine',  [string], $AttribColl)
        $RuntimeParamDic.Add('Engine',  $RuntimeParam)

        return  $RuntimeParamDic
    }
    Process {
        if (-not $PSBoundParameters.ContainsKey('Project')) {
            $PSBoundParameters['Project'] = '.'
        }
        if (-not $PSBoundParameters.ContainsKey('Engine')) {
            $PSBoundParameters['Engine'] = switch ($PSVersionTable.PSVersion.Major) {
                5 {
                    'powershell'
                }
                default {
                    if ($PSVersionTable.PSVersion.PreReleaseLabel) {
                        'pwsh-preview'
                    }
                    else {
                        'pwsh'
                    }
                }
            }
        }
        $parent = switch ($PSBoundParameters['Project']) {
            '.' {
                $PWD.Path
            }
            default {
                $global:PSProfileConfig['_internal']['PSBuildPathMap'][$PSBoundParameters['Project']]
            }
        }
        $command = "$($PSBoundParameters['Engine']) -NoProfile -C `"```$env:NoNugetRestore = "
        if ($NoRestore) {
            $command += "```$true;"
        }
        else {
            $command += "```$false;"
        }
        $command += "Set-Location '$parent'; . .\build.ps1"
        if ($PSBoundParameters.ContainsKey('Task')) {
            $command += " -Task '$($PSBoundParameters['Task'] -join "','")'"
        }
        $command += '"'
        Write-Verbose "Invoking expression: $command"
        Invoke-Expression $command
        if ($NoExit) {
            Push-Location $parent
            cln -Engine $PSBoundParameters['Engine'] -ImportModule
            Pop-Location
        }
    }
}

function global:push {
    [CmdletBinding()]
    Param()
    DynamicParam {
        $ParamAttrib = New-Object System.Management.Automation.ParameterAttribute
        $ParamAttrib.Mandatory = $true
        $ParamAttrib.ParameterSetName = 'Location'
        $ParamAttrib.Position = 0
        $AttribColl = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $AttribColl.Add($ParamAttrib)
        $set = @()
        $set += $global:PSProfileConfig['_internal']['GitPathMap'].Keys
        $set += '~'
        $AttribColl.Add((New-Object System.Management.Automation.ValidateSetAttribute($set)))
        $AttribColl.Add((New-Object System.Management.Automation.AliasAttribute('l')))
        $RuntimeParam = New-Object System.Management.Automation.RuntimeDefinedParameter('Location',  [string], $AttribColl)
        $RuntimeParamDic = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $RuntimeParamDic.Add('Location',  $RuntimeParam)
        if ($global:PSProfileConfig['_internal']['GitPathMap'].ContainsKey('chef-repo')) {
            $ParamAttrib = New-Object System.Management.Automation.ParameterAttribute
            $ParamAttrib.Mandatory = $true
            $ParamAttrib.ParameterSetName = 'Cookbook'
            $AttribColl = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $AttribColl.Add($ParamAttrib)
            $set = (Get-ChildItem (Join-Path $global:PSProfileConfig['_internal']['GitPathMap']['chef-repo'] 'cookbooks') -Directory).Name
            $AttribColl.Add((New-Object System.Management.Automation.ValidateSetAttribute($set)))
            $AttribColl.Add((New-Object System.Management.Automation.AliasAttribute('c')))
            $RuntimeParam = New-Object System.Management.Automation.RuntimeDefinedParameter('Cookbook',  [string], $AttribColl)
            $RuntimeParamDic.Add('Cookbook',  $RuntimeParam)
        }
        return  $RuntimeParamDic
    }
    Process {
        $target = switch ($PSCmdlet.ParameterSetName) {
            Location {
                if ($PSBoundParameters['Location'] -eq '~') {
                    '~'
                }
                else {
                    $global:PSProfileConfig['_internal']['GitPathMap'][$PSBoundParameters['Location']]
                }
            }
            Cookbook {
                [System.IO.Path]::Combine($global:PSProfileConfig['_internal']['GitPathMap']['chef-repo'],'cookbooks',$PSBoundParameters['Cookbook'])
            }
        }
        Write-Verbose "Pushing location to: $($target.Replace($env:HOME,'~'))"
        Push-Location $target
    }
}
function global:cadd {
    [CmdletBinding()]
    Param()
    DynamicParam {
        $ParamAttrib = New-Object System.Management.Automation.ParameterAttribute
        $ParamAttrib.Mandatory = $true
        $ParamAttrib.ParameterSetName = 'Location'
        $ParamAttrib.Position = 0
        $AttribColl = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $AttribColl.Add($ParamAttrib)
        $set = @()
        $set += $global:PSProfileConfig['_internal']['GitPathMap'].Keys
        $set += '.'
        $AttribColl.Add((New-Object System.Management.Automation.ValidateSetAttribute($set)))
        $AttribColl.Add((New-Object System.Management.Automation.AliasAttribute('l')))
        $RuntimeParam = New-Object System.Management.Automation.RuntimeDefinedParameter('Location',  [string], $AttribColl)
        $RuntimeParamDic = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $RuntimeParamDic.Add('Location',  $RuntimeParam)
        if ($global:PSProfileConfig['_internal']['GitPathMap'].ContainsKey('chef-repo')) {
            $ParamAttrib = New-Object System.Management.Automation.ParameterAttribute
            $ParamAttrib.Mandatory = $true
            $ParamAttrib.ParameterSetName = 'Cookbook'
            $AttribColl = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $AttribColl.Add($ParamAttrib)
            $set = (Get-ChildItem (Join-Path $global:PSProfileConfig['_internal']['GitPathMap']['chef-repo'] 'cookbooks') -Directory).Name
            $AttribColl.Add((New-Object System.Management.Automation.ValidateSetAttribute($set)))
            $AttribColl.Add((New-Object System.Management.Automation.AliasAttribute('c')))
            $RuntimeParam = New-Object System.Management.Automation.RuntimeDefinedParameter('Cookbook',  [string], $AttribColl)
            $RuntimeParamDic.Add('Cookbook',  $RuntimeParam)
        }
        return  $RuntimeParamDic
    }
    Process {
        $target = switch ($PSCmdlet.ParameterSetName) {
            Location {
                if ($PSBoundParameters['Location'] -eq '.') {
                    $PWD.Path
                }
                else {
                    $global:PSProfileConfig['_internal']['GitPathMap'][$PSBoundParameters['Location']]
                }
            }
            Cookbook {
                [System.IO.Path]::Combine($global:PSProfileConfig['_internal']['GitPathMap']['chef-repo'],'cookbooks',$PSBoundParameters['Cookbook'])
            }
        }
        Write-Verbose "Adding location to Code workspace: $($target.Replace($env:HOME,'~'))"
        $code = (Get-Command code -All | Where-Object { $_.CommandType -ne 'Function' })[0].Source
        & $code --add $target
    }
}

function global:code {
    [CmdletBinding(DefaultParameterSetName = 'Location')]
    Param (
        [parameter(ValueFromPipeline,ParameterSetName = 'InputObject')]
        [Object]
        $InputObject,
        [parameter(ValueFromPipeline,ParameterSetName = 'InputObject')]
        [Switch]
        $AsJob,
        [parameter(ValueFromRemainingArguments,ParameterSetName = 'Location')]
        [parameter(ValueFromRemainingArguments,ParameterSetName = 'Cookbook')]
        [Object]
        $Arguments
    )
    DynamicParam {
        $ParamAttrib = New-Object System.Management.Automation.ParameterAttribute
        $ParamAttrib.Mandatory = $true
        $ParamAttrib.ParameterSetName = 'Location'
        $ParamAttrib.Position = 0
        $AttribColl = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $AttribColl.Add($ParamAttrib)
        if ($null -ne $global:PSProfileConfig['_internal']['GitPathMap'].Keys) {
            $set = @()
            $set += $global:PSProfileConfig['_internal']['GitPathMap'].Keys
            $set += '.'
            $AttribColl.Add((New-Object System.Management.Automation.ValidateSetAttribute($set)))
        }
        $AttribColl.Add((New-Object System.Management.Automation.AliasAttribute('l')))
        $RuntimeParam = New-Object System.Management.Automation.RuntimeDefinedParameter('Location',  [string], $AttribColl)
        $RuntimeParamDic = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $RuntimeParamDic.Add('Location',  $RuntimeParam)
        if ($global:PSProfileConfig['_internal']['GitPathMap'].ContainsKey('chef-repo')) {
            $ParamAttrib = New-Object System.Management.Automation.ParameterAttribute
            $ParamAttrib.Mandatory = $true
            $ParamAttrib.ParameterSetName = 'Cookbook'
            $AttribColl = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $AttribColl.Add($ParamAttrib)
            $set = (Get-ChildItem (Join-Path $global:PSProfileConfig['_internal']['GitPathMap']['chef-repo'] 'cookbooks') -Directory).Name
            $AttribColl.Add((New-Object System.Management.Automation.ValidateSetAttribute($set)))
            $AttribColl.Add((New-Object System.Management.Automation.AliasAttribute('c')))
            $RuntimeParam = New-Object System.Management.Automation.RuntimeDefinedParameter('Cookbook',  [string], $AttribColl)
            $RuntimeParamDic.Add('Cookbook',  $RuntimeParam)
        }
        return  $RuntimeParamDic
    }
    Begin {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            $collection = New-Object System.Collections.Generic.List[object]
        }
    }
    Process {
        $code = (Get-Command code -All | Where-Object { $_.CommandType -ne 'Function' })[0].Source
        $target = switch ($PSCmdlet.ParameterSetName) {
            Location {
                if ($PSBoundParameters['Location'] -eq '.') {
                    $PWD.Path
                }
                else {
                    $global:PSProfileConfig['_internal']['GitPathMap'][$PSBoundParameters['Location']]
                }
            }
            Cookbook {
                [System.IO.Path]::Combine($global:PSProfileConfig['_internal']['GitPathMap']['chef-repo'],'cookbooks',$PSBoundParameters['Cookbook'])
            }
        }
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            $collection.Add($InputObject)
        }
        else {
            Write-Verbose "Running command: & `$code $($PSBoundParameters[$PSCmdlet.ParameterSetName]) $Arguments"
            & $code $target $Arguments
        }
    }
    End {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            if ($AsJob) {
                Write-Verbose "Piping input to Code: `$collection | Start-Job {& $code -}"
                $collection | Start-Job { & $code - } -InitializationScript { $code = (Get-Command code -All | Where-Object { $_.CommandType -ne 'Function' })[0].Source }
            }
            else {
                Write-Verbose "Piping input to Code: `$collection | & `$code -"
                $collection | & $code -
            }
        }
    }
}

# PowerShell parameter completion shim for the dotnet CLI from Scott Hanselman: https://www.hanselman.com/blog/CommandLineTabCompletionForNETCoreCLIInPowerShellOrBash.aspx
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)
    dotnet complete --position $cursorPosition "$wordToComplete" | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

if (Test-Path "C:\Program Files (x86)\Devolutions\Remote Desktop Manager\RemoteDesktopManager.PowerShellModule.psd1") {
    function global:Open-RDPSession {
        [CmdletBinding()]
        Param (
            [parameter(Mandatory = $true,Position = 0,ValueFromPipeline = $true,ParameterSetName = "Name")]
            [String]
            $Name,
            [parameter(Position = 1,ParameterSetName = "Name")]
            [Alias('Host')]
            [String]
            $ComputerName,
            [parameter(Mandatory = $true,ValueFromPipelineByPropertyName = $true,ParameterSetName = "Id")]
            [String]
            $Id
        )
        Begin {
            Write-Verbose "Importing RemoteDesktopManager module"
            Import-Module "C:\Program Files (x86)\Devolutions\Remote Desktop Manager\RemoteDesktopManager.PowerShellModule.psd1" -Verbose:$false
            if ($PSCmdlet.ParameterSetName -eq 'Name') {
                Write-Verbose "Getting template"
                $template = Get-RDMTemplate | Where-Object { $_.Name -eq "RDP - Self Creds" }
                Write-Verbose "Getting session list"
                $sessions = Get-RDMSession
            }
        }
        Process {
            if ($PSCmdlet.ParameterSetName -eq 'Name') {
                $HostName = if ($PSBoundParameters.Keys -contains 'ComputerName') {
                    $PSBoundParameters['ComputerName']
                }
                else {
                    $Name
                }
                if ($existing = $sessions | Where-Object { $_.Name -eq $Name -and $_.Host -eq $HostName }) {
                    Write-Verbose "Opening existing session '$Name' [$HostName]"
                    Open-RDMSession -ID $existing.ID
                    return $existing
                }
                else {
                    Write-Verbose "Creating new session '$Name' [$HostName]"
                    $s = New-RDMSession -Name $Name -Host $HostName -TemplateID $template.ID -Type RDPConfigured
                    Write-Verbose "Saving new session '$Name' [$HostName]"
                    Set-RDMSession $s
                    Write-Verbose "Opening new session '$Name' [$HostName]"
                    $s = Get-RDMSession -GroupName 'PS Generated' | Where-Object { $_.Name -eq $Name }
                    Open-RDMSession -ID $s.Id
                    return $s
                }
            }
            else {
                Write-Verbose "Opening session ID '$Id'"
                Open-RDMSession -ID $Id
            }
        }
    }
}
