
function global:push {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory,Position = 0,ParameterSetName = 'Location')]
        [String]
        $Location
    )
    DynamicParam {
        $RuntimeParamDic = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        if ($global:PSProfileConfig['_internal']['GitPathMap'].ContainsKey('chef-repo')) {
            $ParamAttrib = New-Object System.Management.Automation.ParameterAttribute
            $ParamAttrib.Mandatory = $true
            $ParamAttrib.ParameterSetName = 'Cookbook'
            $AttribColl = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $AttribColl.Add($ParamAttrib)
            $set = (Get-ChildItem (Join-Path $global:PSProfileConfig['_internal']['GitPathMap']['chef-repo'] 'cookbooks') -Directory).Name
            $AttribColl.Add((New-Object System.Management.Automation.ValidateSetAttribute($set)))
            $AttribColl.Add((New-Object System.Management.Automation.AliasAttribute('c')))
            $RuntimeParam = New-Object System.Management.Automation.RuntimeDefinedParameter('Cookbook',  [string], $AttribColl)
            $RuntimeParamDic.Add('Cookbook',  $RuntimeParam)
        }
        return  $RuntimeParamDic
    }
    Process {
        $target = switch ($PSCmdlet.ParameterSetName) {
            Location {
                if ($global:PSProfileConfig['_internal']['GitPathMap'].ContainsKey($PSBoundParameters['Location'])) {
                    $global:PSProfileConfig['_internal']['GitPathMap'][$PSBoundParameters['Location']]
                }
                else {
                    $PSBoundParameters['Location']
                }
            }
            Cookbook {
                [System.IO.Path]::Combine($global:PSProfileConfig['_internal']['GitPathMap']['chef-repo'],'cookbooks',$PSBoundParameters['Cookbook'])
            }
        }
        Write-Verbose "Pushing location to: $($target.Replace($env:HOME,'~'))"
        Push-Location $target
    }
}

New-Alias -Name pop -Value Pop-Location -Option AllScope -Scope Global

if ($null -ne $global:PSProfileConfig['_internal']['GitPathMap'].Keys) {
    Register-ArgumentCompleter -CommandName 'push' -ParameterName 'Location' -ScriptBlock {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
        $global:PSProfileConfig['_internal']['GitPathMap'].Keys | Where-Object {$_ -like "$wordToComplete*"} | Sort-Object | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
