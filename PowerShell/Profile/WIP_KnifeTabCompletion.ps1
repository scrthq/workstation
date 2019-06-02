function Get-AliasPattern($Command) {
    $aliases = @($Command) + @(Get-Alias | Where-Object { $_.Definition -eq $Command } | Select-Object -Exp Name)
    "($($aliases -join '|'))"
}

function Expand-KnifeCommand($Command) {
    $res = Invoke-Utf8ConsoleCommand { KnifeTabExpansionInternal $Command $Global:GitStatus }
    $res
}

function Invoke-Utf8ConsoleCommand([ScriptBlock]$Command) {
    $currentEncoding = [Console]::OutputEncoding
    $errorCount = $global:Error.Count
    try {
        # A native executable that writes to stderr AND has its stderr redirected will generate non-terminating
        # error records if the user has set $ErrorActionPreference to Stop. Override that value in this scope.
        $ErrorActionPreference = 'Continue'
        if ($currentEncoding.IsSingleByte) {
            [Console]::OutputEncoding = [Text.Encoding]::UTF8
        }
        & $Command
    }
    finally {
        if ($currentEncoding.IsSingleByte) {
            [Console]::OutputEncoding = $currentEncoding
        }

        # Clear out stderr output that was added to the $Error collection, putting those errors in a module variable
        if ($global:Error.Count -gt $errorCount) {
            $numNewErrors = $global:Error.Count - $errorCount
            $invokeErrors.InsertRange(0, $global:Error.GetRange(0, $numNewErrors))
            if ($invokeErrors.Count -gt 256) {
                $invokeErrors.RemoveRange(256, ($invokeErrors.Count - 256))
            }
            $global:Error.RemoveRange(0, $numNewErrors)
        }
    }
}

function script:knifeCmdOperations($commands, $command, $filter) {
    $commands[$command].Trim() -split '\s+' | Where-Object { $_ -like "$filter*" }
}

function KnifeTabExpansionInternal($lastBlock) {
    $ignoreGitParams = '(?<params>\s+-(?:[aA-zZ0-9]+|-[aA-zZ0-9][aA-zZ0-9-]*)(?:=\S+)?)*'

    switch -regex ($lastBlock -replace "^$(Get-AliasPattern knife) ","") {

        # Handles knife <cmd> <op>
        "^(?<cmd>$($subcommands.Keys -join '|'))\s+(?<op>\S*)$" {
            knifeCmdOperations $subcommands $matches['cmd'] $matches['op']
        }

        # Handles git flow <cmd> <op>
        "^flow (?<cmd>$($gitflowsubcommands.Keys -join '|'))\s+(?<op>\S*)$" {
            knifeCmdOperations $gitflowsubcommands $matches['cmd'] $matches['op']
        }

        # Handles git flow <command> <op> <name>
        "^flow (?<command>\S*)\s+(?<op>\S*)\s+(?<name>\S*)$" {
            gitFeatures $matches['name'] $matches['command']
        }

        # Handles git remote (rename|rm|set-head|set-branches|set-url|show|prune) <stash>
        "^remote.* (?:rename|rm|set-head|set-branches|set-url|show|prune).* (?<remote>\S*)$" {
            gitRemotes $matches['remote']
        }

        # Handles git stash (show|apply|drop|pop|branch) <stash>
        "^stash (?:show|apply|drop|pop|branch).* (?<stash>\S*)$" {
            gitStashes $matches['stash']
        }

        # Handles git bisect (bad|good|reset|skip) <ref>
        "^bisect (?:bad|good|reset|skip).* (?<ref>\S*)$" {
            gitBranches $matches['ref'] $true
        }

        # Handles git tfs unshelve <shelveset>
        "^tfs +unshelve.* (?<shelveset>\S*)$" {
            gitTfsShelvesets $matches['shelveset']
        }

        # Handles git branch -d|-D|-m|-M <branch name>
        # Handles git branch <branch name> <start-point>
        "^branch.* (?<branch>\S*)$" {
            gitBranches $matches['branch']
        }

        # Handles git <cmd> (commands & aliases)
        "^(?<cmd>\S*)$" {
            gitCommands $matches['cmd'] $TRUE
        }

        # Handles git help <cmd> (commands only)
        "^help (?<cmd>\S*)$" {
            gitCommands $matches['cmd'] $FALSE
        }

        # Handles git push remote <ref>:<branch>
        # Handles git push remote +<ref>:<branch>
        "^push${ignoreGitParams}\s+(?<remote>[^\s-]\S*).*\s+(?<force>\+?)(?<ref>[^\s\:]*\:)(?<branch>\S*)$" {
            gitRemoteBranches $matches['remote'] $matches['ref'] $matches['branch'] -prefix $matches['force']
        }

        # Handles git push remote <ref>
        # Handles git push remote +<ref>
        # Handles git pull remote <ref>
        "^(?:push|pull)${ignoreGitParams}\s+(?<remote>[^\s-]\S*).*\s+(?<force>\+?)(?<ref>[^\s\:]*)$" {
            gitBranches $matches['ref'] -prefix $matches['force']
            gitTags $matches['ref'] -prefix $matches['force']
        }

        # Handles git pull <remote>
        # Handles git push <remote>
        # Handles git fetch <remote>
        "^(?:push|pull|fetch)${ignoreGitParams}\s+(?<remote>\S*)$" {
            gitRemotes $matches['remote']
        }

        # Handles git <cmd> <ref>
        "^commit.*-C\s+(?<ref>\S*)$" {
            gitBranches $matches['ref'] $true
        }

        # Handles git checkout <ref>
        "^(?:checkout).* (?<ref>\S*)$" {
            & {
                gitBranches $matches['ref'] $true
                gitRemoteUniqueBranches $matches['ref']
                gitTags $matches['ref']
                # Return only unique branches (to eliminate duplicates where the branch exists locally and on the remote)
            } | Select-Object -Unique
        }

        # Handles git worktree add <path> <ref>
        "^worktree add.* (?<files>\S+) (?<ref>\S*)$" {
            gitBranches $matches['ref']
        }

        # Handles git <cmd> <ref>
        "^(?:cherry|cherry-pick|diff|difftool|log|merge|rebase|reflog\s+show|reset|revert|show).* (?<ref>\S*)$" {
            gitBranches $matches['ref'] $true
            gitTags $matches['ref']
        }

        # Handles git <cmd> --<param>=<value>
        "^(?<cmd>$gitCommandsWithParamValues).* --(?<param>[^=]+)=(?<value>\S*)$" {
            expandParamValues $matches['cmd'] $matches['param'] $matches['value']
        }

        # Handles git <cmd> --<param>
        "^(?<cmd>$gitCommandsWithLongParams).* --(?<param>\S*)$" {
            expandLongParams $longGitParams $matches['cmd'] $matches['param']
        }

        # Handles git <cmd> -<shortparam>
        "^(?<cmd>$gitCommandsWithShortParams).* -(?<shortparam>\S*)$" {
            expandShortParams $shortGitParams $matches['cmd'] $matches['shortparam']
        }

        # Handles git pr alias
        "vsts\.pr\s+(?<op>\S*)$" {
            knifeCmdOperations $subcommands 'vsts.pr' $matches['op']
        }

        # Handles git pr <cmd> --<param>
        "vsts\.pr\s+(?<cmd>$vstsCommandsWithLongParams).*--(?<param>\S*)$"
        {
            expandLongParams $longVstsParams $matches['cmd'] $matches['param']
        }

        # Handles git pr <cmd> -<shortparam>
        "vsts\.pr\s+(?<cmd>$vstsCommandsWithShortParams).*-(?<shortparam>\S*)$"
        {
            expandShortParams $shortVstsParams $matches['cmd'] $matches['shortparam']
        }
    }
}

$PowerTab_RegisterTabExpansion = if (Get-Module -Name powertab) { Get-Command Register-TabExpansion -Module powertab -ErrorAction SilentlyContinue }
if ($PowerTab_RegisterTabExpansion) {
    & $PowerTab_RegisterTabExpansion "knife.bat" -Type Command {
        param($Context, [ref]$TabExpansionHasOutput, [ref]$QuoteSpaces)  # 1:

        $line = $Context.Line
        $lastBlock = [regex]::Split($line, '[|;]')[-1].TrimStart()
        $TabExpansionHasOutput.Value = $true
        Expand-KnifeCommand $lastBlock
    }
    return
}

if (Test-Path Function:\TabExpansion -and -not (Test-Path Function:\TabExpansionBackup)) {
    Rename-Item Function:\TabExpansion TabExpansionBackup
}

function TabExpansion($line, $lastWord) {
    $lastBlock = [regex]::Split($line, '[|;]')[-1].TrimStart()

    switch -regex ($lastBlock) {
        "^$(Get-AliasPattern knife) (.*)" { Expand-KnifeCommand $lastBlock }
        # Execute git tab completion for all git-related commands
        "^$(Get-AliasPattern git) (.*)" { Expand-GitCommand $lastBlock }
        "^$(Get-AliasPattern tgit) (.*)" { Expand-GitCommand $lastBlock }
        "^$(Get-AliasPattern gitk) (.*)" { Expand-GitCommand $lastBlock }
        "^$(Get-AliasPattern Remove-GitBranch) (.*)" { Expand-GitCommand $lastBlock }

        # Fall back on existing tab expansion
        default {
            if (Test-Path Function:\TabExpansionBackup) {
                TabExpansionBackup $line $lastWord
            }
        }
    }
}
