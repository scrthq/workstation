function Invoke-Profile {
    [CmdletBinding()]
    Param (
        [parameter(Mandatory = $false,Position = 0)]
        [ValidateSet("Fast","Slim","Full","Demo","macOS",$null)]
        [String]
        $Level = $null
    )
    . $profile.CurrentUserAllHosts $Level
}

function Disable-PoshGit {
    $env:DisablePoshGit = $true
}

function Enable-PoshGit {
    $env:DisablePoshGit = $false
}

function Syntax {
    [CmdletBinding()]
    param (
        $Command
    )
    $check = Get-Command -Name $Command
    $params = @{
        Name   = if ($check.CommandType -eq 'Alias') {
            Get-Command -Name $check.Definition
        }
        else {
            $Command
        }
        Syntax = $true
    }
    (Get-Command @params) -replace '(\s(?=\[)|\s(?=-))', "`r`n "
}

function Show-Colors ([Switch]$Grid) {
    $colors = [enum]::GetValues([System.ConsoleColor])
    if ($Grid) {
        Foreach ($bgcolor in $colors) {
            Foreach ($fgcolor in $colors) {
                Write-Host "$fgcolor|"  -ForegroundColor $fgcolor -BackgroundColor $bgcolor -NoNewLine
            }
            Write-Host " on $bgcolor"
        }
    }
    else {
        $max = ($colors | ForEach-Object { "$_ ".Length } | Measure-Object -Maximum).Maximum
        foreach ( $color in $colors ) {
            Write-Host (" {0,2} {1,$max} " -f [int]$color,$color) -NoNewline
            Write-Host "$color" -Foreground $color
        }
    }
}
