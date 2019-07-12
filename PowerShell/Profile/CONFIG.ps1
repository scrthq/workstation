$global:PSProfileConfig = @{
    _internal       = @{
        ProfileLoadStart = Get-Date
    }
    Settings        = @{
        Prompt                = 'SlimDrop'
        PSVersionStringLength = 3
    }
    Variables       = @{
        Environment = @{ }
        Global      = @{
            PathAliasDirectorySeparator    = [System.IO.Path]::DirectorySeparatorChar
            AltPathAliasDirectorySeparator = [char]0xe0b1
        }
    }
    GitPaths        = @{
        Work     = 'WorkGit'
        Personal = 'ScrtGit'
        Other    = 'E:\Git'
    }
    PathAliases     = @(
        @{
            Alias = '~'
            Path  = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
        }
    )
    GistsToInvoke   = @(
        <#
        @{
            Id       = '6b2dfc7efc459399c872d23a663d7914'
            Files    = @('__init__.ps1','_Meta.ps1','_DemoTools.ps1','_FunTools.ps1','_Prompts.ps1','_PSReadlineSettings.ps1')
            Metadata = @{
                Description = 'PowerShell Profile Components'
            }
        }
        #>
    )
    ModulesToImport = @(
        'PSChef'
        'PSToolbelt'
        'MyConfig'
    )
}
