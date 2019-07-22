function Install-LatestModule {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory,Position = 0,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [String]
        $Name,
        [Parameter()]
        [Switch]
        $ConfirmNotImported
    )
    Process {
        if ($ConfirmNotImported -and (Get-Module $Name)) {
            throw "$Name cannot be loaded if trying to install!"
        }
        else {
            try {
                # Uninstall all installed versions
                Get-Module $Name -ListAvailable | Uninstall-Module -Verbose

                # Install the latest module from the PowerShell Gallery
                Install-Module $Name -Repository PSGallery -Scope CurrentUser -Verbose -AllowClobber -SkipPublisherCheck -AcceptLicense

                # Import the freshly installed module
                Import-Module $Name

                # Test that everything still works as expected
                Get-GSUser | Select-Object @{N="ModuleVersion";E={(Get-Module $Name).Version}},PrimaryEmail,OrgUnitPath
            } catch {
                throw
            }
        }
    }
}

Register-ArgumentCompleter -CommandName 'Install-LatestModule' -ParameterName 'Name' -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
    (Get-Module "$wordToComplete*" -ListAvailable).Name | Sort-Object | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
