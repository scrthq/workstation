if ($PSVersionTable.PSVersion.Major -lt 6 -or $IsWindows) {
    $env:PYTHONIOENCODING = "UTF-8"
}

function global:Test-ADCredential {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory,Position = 0)]
        [string]
        $UserName,
        [parameter(Mandatory,Position = 1)]
        [object]
        $Password
    )
    $pw = if ($Password -is [SecureString]) {
        (New-Object System.Management.Automation.PSCredential $UserName,$Password).GetNetworkCredential().Password
    }
    elseif ($Password -is [String]) {
        $Password
    }
    else {
        throw "Password supplied was neither a String or a SecureString! Unable to validate"
    }
    $CurrentDomain = "LDAP://" + ([ADSI]"").distinguishedName
    $domain = New-Object System.DirectoryServices.DirectoryEntry($CurrentDomain,$UserName,$pw)
    $null -ne $domain.name
}

function global:Convert-Duration {
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

function global:Get-PublicIp {
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
