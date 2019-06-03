class ScrtConfigSettings {
    [String] $Prompt = 'Slim'
    [Int]    $PSVersionStringLength = 3
    ScrtConfigSettings(){}
    [void] setPrompt([String]$Prompt) {
        Write-Host -ForegroundColor Magenta "Prompt has been set to $($Prompt)-alt!"
        $this.Prompt = "$Prompt-alt"
    }
}

class ScrtConfigVariables {
    [Hashtable] $Environment
    [Hashtable] $Global
    [Hashtable] $Script
    ScrtConfigVariables(){}
}


class ScrtConfig {
    hidden [Hashtable]    $_internal
    [Hashtable]           $Settings
    [ScrtConfigVariables] $Variables = [ScrtConfigVariables]::new()

    ScrtConfig(){
        $this._internal = @{
            ProfileLoadStart = Get-Date
        }
    }

    ScrtConfig([Hashtable]$Settings) {
        $this._internal = @{
            ProfileLoadStart = Get-Date
        }
        $this.Settings = $Settings
    }
}
