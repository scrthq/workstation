function New-ScratchPad {
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0)]
        [String]
        $FileName = "Scratch_$(Get-Date -Format 'yyyy-MM-dd').ps1",
        [Parameter()]
        [String]
        $Path = "H:\My Drive\VSNotes\Scratch Pads"
    )
    Process {
        code.cmd "$(Join-Path $Path $FileName)"
    }
}
function Unlock-Screen {
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0)]
        [String[]]
        $Process = @('LogiOverlay','WindowsInternal.ComposableShell.Experiences.TextInput.InputApp','LockApp','StartMenuExperienceHost')
    )
    Process {
        foreach ($proc in $Process) {
            if ($running = Get-Process $proc*) {
                Write-Verbose "Killing running process: $($running.Name)"
                $running | Stop-Process -Force
            }
            else {
                Write-Warning "Skipped non-running process: $proc"
            }
        }
    }
}
function Get-ADMemberOf {
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [Microsoft.ActiveDirectory.Management.ADUser]
        [Alias('SamAccountName')]
        $Identity = $env:USERNAME
    )
    Process {
        (Get-ADUser $Identity -Properties MemberOf).MemberOf | Sort-Object
    }
}


function Read-Prompt {
    [CmdletBinding()]
    Param (
        [parameter(Mandatory = $true,Position = 0)]
        $Options,
        [parameter(Mandatory = $false)]
        [String]
        $Title = "Picky Choosy Time",
        [parameter(Mandatory = $false)]
        [String]
        $Message = "Which do you prefer?",
        [parameter(Mandatory = $false)]
        [Int]
        $Default = 0
    )
    Process {
        $opt = @()
        foreach ($option in $Options) {
            switch ($option.GetType().Name) {
                Hashtable {
                    foreach ($key in $option.Keys) {
                        $opt += New-Object System.Management.Automation.Host.ChoiceDescription "$($key)","$($option[$key])"
                    }
                }
                String {
                    $opt += New-Object System.Management.Automation.Host.ChoiceDescription "$option",$null
                }
            }
        }
        $choices = [System.Management.Automation.Host.ChoiceDescription[]] $opt
        $answer = $host.ui.PromptForChoice($Title, $Message, $choices, $Default)
        $choices[$answer].Label -replace "&"
    }
}

function Get-IPOwner {
    [CmdletBinding()]
    Param (
        [parameter(Mandatory = $true,Position = 0,ValueFromPipeline = $true)]
        [String]
        $IP,
        [parameter(Mandatory = $false)]
        [ValidateSet("XML","JSON","Text","HTML")]
        [String]
        $Format = "Text"
    )
    $fmtHash = @{
        XML  = "application/xml"
        JSON = "application/json"
        Text = "text/plain"
        HTML = "text/html"
    }
    $headers = @{
        Accept = $fmtHash[$Format]
    }
    $URI = "http://whois.arin.net/rest/ip/$IP"
    $result = Invoke-RestMethod -Method Get -Uri $URI -Headers $headers
    if ($Format -eq "Text") {
        $result = $result -split "`n" | Where-Object { $_ -notlike "#*" -and ![string]::IsNullOrWhiteSpace($_) }
    }
    elseif ($Format -eq "JSON") {
        $result = $result.net
    }
    return $result
}
