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

function Colors {
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
