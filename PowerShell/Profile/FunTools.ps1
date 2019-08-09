Function USA {
    Write-host "`n        'MURICA"
    Write-host "------------------------"
    Write-host "░░░░░░░░░░" -BackgroundColor Blue -NoNewline
    Write-host "              " -BackgroundColor red
    Write-host "░░░░░░░░░░" -BackgroundColor Blue -NoNewline
    Write-host "              " -BackgroundColor White
    Write-host "░░░░░░░░░░" -BackgroundColor Blue -NoNewline
    Write-host "              " -BackgroundColor red
    Write-host "                        " -BackgroundColor White
    Write-host "                        " -BackgroundColor red
    Write-host "                        " -BackgroundColor White
    Write-host "                        `n" -BackgroundColor red
}
function FRANCE {
    Write-host " FRANCE "
    Write-host "        " -BackgroundColor Blue -NoNewline
    Write-host "        " -BackgroundColor White -NoNewline
    Write-host "        " -BackgroundColor Red
    Write-host "        " -BackgroundColor Blue -NoNewline
    Write-host "        " -BackgroundColor White -NoNewline
    Write-host "        " -BackgroundColor Red
    Write-host "        " -BackgroundColor Blue -NoNewline
    Write-host "        " -BackgroundColor White -NoNewline
    Write-host "        " -BackgroundColor Red
    Write-host "        " -BackgroundColor Blue -NoNewline
    Write-host "        " -BackgroundColor White -NoNewline
    Write-host "        " -BackgroundColor Red
    Write-host "        " -BackgroundColor Blue -NoNewline
    Write-host "        " -BackgroundColor White -NoNewline
    Write-host "        " -BackgroundColor Red
}

function Fabulous {
    Write-host "`n     Extra Fabulous"
    Write-host "------------------------"
    Write-host "                        " -BackgroundColor Red
    Write-host "                        " -BackgroundColor DarkRed
    Write-host "                        " -BackgroundColor Yellow
    Write-host "                        " -BackgroundColor Green
    Write-host "                        " -BackgroundColor Blue
    Write-host "                        `n" -BackgroundColor Magenta
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
