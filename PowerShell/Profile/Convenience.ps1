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