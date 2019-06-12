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
