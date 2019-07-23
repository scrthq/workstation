function Get-Definition {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory,Position = 0)]
        [String]
        $Command
    )
    Process {
        try {
            $Defintion = (Get-Command $Command -ErrorAction Stop).Definition
            "function $Command {$Defintion}"
        }
        catch {
            throw
        }
    }
}

Set-Alias -Name def -Value Get-Definition -Option AllScope -Scope Global

Register-ArgumentCompleter -CommandName 'Get-Definition' -ParameterName 'Command' -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
    (Get-Command "$wordToComplete*").Name | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
