if ($PSVersionTable.PSVersion.Major -lt 6 -or $IsWindows) {
    $env:PYTHONIOENCODING = "UTF-8"
}

function Get-Tree {
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0)]
        [String]
        $Path = $PWD.Path,
        [Parameter()]
        [Alias('l')]
        [int]
        $Level = [int]::MaxValue,
        [Parameter()]
        [Alias('d')]
        [Switch]
        $Directory,
        [Parameter()]
        [Alias('f')]
        [Switch]
        $Format,
        [Parameter(DontShow)]
        [int]
        $Indent = 0,
        [Parameter(DontShow)]
        [Switch]
        $IsLast
    )
    Begin {
        $mid = '├──'
        $end = '└──'
        $esc = [char]27
    }
    Process {
        if (-not $Indent) {
            "${esc}[94m{0}${esc}[0m" -f $Path
        }
        $subs = Get-ChildItem -Path $Path -Directory:$Directory
        $i = 0
        $subs | ForEach-Object {
            $i++
            $glyph = if ($i -ge $subs.Count) {
                $end
            }
            else {
                $mid
            }
            $front = if ($Indent) {
                if ($IsLast) {
                    ((' ' * 3 * $Indent) -replace '^\s','│') + $glyph
                }
                else {
                    ((' ' * 3 * ($Indent - 1)) -replace '^\s','│') + '│  ' + $glyph
                }
            }
            else {
                $glyph
            }
            $name = if ($Format -and $_.PSIsContainer) {
                "/${esc}[33m{0}${esc}[0m" -f $_.Name
            }
            elseif ($_.PSIsContainer) {
                "${esc}[33m{0}${esc}[0m" -f $_.Name
            }
            else {
                "${esc}[37m{0}${esc}[0m" -f $_.Name
            }
            "{0} {1}" -f $front,$name
            if ($_.PSIsContainer -and $Indent -lt $Level) {
                Get-Tree -Path $_.FullName -Level $Level -Indent ($Indent + 1) -Directory:$Directory -IsLast:$($i -ge $subs.Count) -Format:$Format
            }
        }
    }
}

function Test-ADCredential {
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
    Import-Module EditorServicesCommandSuite -ErrorAction SilentlyContinue -Global -Force
    Import-Module EditorServicesCommandSuite -ErrorAction SilentlyContinue -Global -Force # Twice because: https://github.com/SeeminglyScience/EditorServicesCommandSuite/issues/40
    Import-EditorCommand -Module EditorServicesCommandSuite -Force
}

function Set-ProcessPriority {
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
    function Open-RDPSession {
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

function Show-Colors {
    [CmdletBinding()]
    Param (
        [parameter(Position = 0)]
        [ValidateSet('Grid','TrueColor','Default')]
        $Style = 'Default'
    )
    Begin {
        $colors = [enum]::GetValues([System.ConsoleColor])
    }
    Process {
        switch ($Style) {
            Grid {
                foreach ($bgcolor in $colors) {
                    Foreach ($fgcolor in $colors) {
                        Write-Host "$fgcolor|"  -ForegroundColor $fgcolor -BackgroundColor $bgcolor -NoNewLine
                    }
                    Write-Host " on $bgcolor"
                }
            }
            Default {
                $max = ($colors | ForEach-Object { "$_ ".Length } | Measure-Object -Maximum).Maximum
                foreach ( $color in $colors ) {
                    Write-Host (" {0,2} {1,$max} " -f [int]$color,$color) -NoNewline
                    Write-Host "$color" -Foreground $color
                }
            }
            TrueColor {
                # Borrowed from: https://raw.githubusercontent.com/Maximus5/ConEmu/master/Release/ConEmu/Addons/AnsiColors24bit.ps1
                # In the current ConEmu version TrueColor is available
                # only in the lower part of console buffer
                $h = [Console]::WindowHeight
                $w = [Console]::BufferWidth
                $y = ([Console]::BufferHeight - $h)
                # Clean console contents (this will clean TrueColor attributes)
                Write-Host (([char]27) + "[32766S")
                # Apply default powershell console attributes
                Clear-Host
                # Ensure that we are in the bottom of the buffer
                try {
                    [Console]::SetWindowPosition(0,$y)
                    [Console]::SetCursorPosition(0,$y)
                }
                catch {
                    Write-Host (([char]27) + "[32766H")
                }
                # Header
                $title = " Printing 24bit gradient with ANSI sequences using powershell"
                Write-Host (([char]27) + "[m" + $title)
                # Run cycles. Use {ESC [ 48 ; 2 ; R ; G ; B m} to set background
                # RGB color of the next printing character (space in this example)
                $l = 0
                $h -= 3
                $w -= 2
                while ($l -lt $h) {
                    $b = [int]($l * 255 / $h)
                    $c = 0
                    Write-Host -NoNewLine (([char]27) + "[m ")
                    while ($c -lt $w) {
                        $r = [int]($c * 255 / $w)
                        Write-Host -NoNewLine (([char]27) + "[48;2;" + $r + ";255;" + $b + "m ")
                        $c++
                    }
                    Write-Host (([char]27) + "[m ")
                    $l++
                }
                # Footer
                Write-Host " Gradient done"
            }
        }
    }
}

function Get-InstalledSoftware {
    <#
    .SYNOPSIS
        Pull software details from registry on one or more computers
    .DESCRIPTION
        Pull software details from registry on one or more computers.  Details:
            -This avoids the performance impact and potential danger of using the WMI Win32_Product class
            -The computer name, display name, publisher, version, uninstall string and install date are included in the results
            -Remote registry must be enabled on the computer(s) you query
            -This command must run with privileges to query the registry of the remote system(s)
            -Running this in a 32 bit PowerShell session on a 64 bit computer will limit your results to 32 bit software and result in double entries in the results
    .PARAMETER ComputerName
        One or more computers to pull software list from.
    .PARAMETER DisplayName
        If specified, return only software with DisplayNames that match this parameter (uses -match operator)
    .PARAMETER Publisher
        If specified, return only software with Publishers that match this parameter (uses -match operator)
    .EXAMPLE
        #Pull all software from c-is-ts-91, c-is-ts-92, format in a table
            Get-InstalledSoftware c-is-ts-91, c-is-ts-92 | Format-Table -AutoSize
    .EXAMPLE
        #pull software with publisher matching microsoft and displayname matching lync from c-is-ts-91
            "c-is-ts-91" | Get-InstalledSoftware -DisplayName lync -Publisher microsoft | Format-Table -AutoSize
    .LINK
        http://gallery.technet.microsoft.com/scriptcenter/Get-InstalledSoftware-Get-5607a465
    .FUNCTIONALITY
        Computers
    #>
    param (
        [Parameter(Position = 0,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('CN', '__SERVER', 'Server', 'Computer')]
        [string[]]
        $ComputerName = $env:computername,
        [Parameter()]
        [string]
        $DisplayName = $null,
        [Parameter()]
        [string]
        $Publisher = $null
    )
    Begin {
        $UninstallKeys = "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        "SOFTWARE\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall"
    }
    Process {
        :computerLoop foreach ($computer in $computername) {
            Try {
                $reg = [microsoft.win32.registrykey]::OpenRemoteBaseKey('LocalMachine', $computer)
            }
            Catch {
                Write-Error "Error:  Could not open LocalMachine hive on $computer`: $_"
                Write-Verbose "Check Connectivity, permissions, and Remote Registry service for '$computer'"
                Continue
            }
            foreach ($uninstallKey in $UninstallKeys) {
                Try {
                    $regkey = $null
                    $regkey = $reg.OpenSubKey($UninstallKey)
                    if ($regkey) {
                        $subkeys = $regkey.GetSubKeyNames()
                        foreach ($key in $subkeys) {
                            $thisKey = $UninstallKey + "\\" + $key
                            $thisSubKey = $null
                            $thisSubKey = $reg.OpenSubKey($thisKey)
                            if ($thisSubKey) {
                                try {
                                    $dispName = $thisSubKey.GetValue("DisplayName")
                                    $pubName = $thisSubKey.GetValue("Publisher")
                                    if ( $dispName -and
                                        (-not $DisplayName -or $dispName -match $DisplayName ) -and
                                        (-not $Publisher -or $pubName -match $Publisher )
                                    ) {
                                        New-Object PSObject -Property @{
                                            ComputerName    = $computer
                                            DisplayName     = $dispname
                                            Publisher       = $pubName
                                            Version         = $thisSubKey.GetValue("DisplayVersion")
                                            UninstallString = $thisSubKey.GetValue("UninstallString")
                                            InstallDate     = $thisSubKey.GetValue("InstallDate")
                                        } | Select-Object ComputerName, DisplayName, Publisher, Version, UninstallString, InstallDate
                                    }
                                }
                                Catch {
                                    Write-Error "Unknown error: $_"
                                    Continue
                                }
                            }
                        }
                    }
                }
                Catch {
                    Write-Verbose "Could not open key '$uninstallkey' on computer '$computer': $_"
                    if ($_ -match "Requested registry access is not allowed") {
                        Write-Error "Registry access to $computer denied.  Check your permissions.  Details: $_"
                        continue computerLoop
                    }
                }
            }
        }
    }
}
