function global:Open-Item {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    Param (
        [parameter(Mandatory,Position = 0,ParameterSetName = 'Path')]
        [String]
        $Path
    )
    DynamicParam {
        if ($global:PSProfileConfig['_internal']['GitPathMap'].ContainsKey('chef-repo')) {
            $RuntimeParamDic = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
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
            Path {
                if ($PSBoundParameters['Path'] -eq '.') {
                    $PWD.Path
                }
                elseif ($null -ne $global:PSProfileConfig['_internal']['GitPathMap'].Keys) {
                    if ($global:PSProfileConfig['_internal']['GitPathMap'].ContainsKey($PSBoundParameters['Path'])) {
                        $global:PSProfileConfig['_internal']['GitPathMap'][$PSBoundParameters['Path']]
                    }
                    else {
                        $PSBoundParameters['Path']
                    }
                }
                else {
                    $PSBoundParameters['Path']
                }
            }
            Cookbook {
                [System.IO.Path]::Combine($global:PSProfileConfig['_internal']['GitPathMap']['chef-repo'],'cookbooks',$PSBoundParameters['Cookbook'])
            }
        }
        Write-Verbose "Running command: Invoke-Item $($PSBoundParameters[$PSCmdlet.ParameterSetName])"
        Invoke-Item $target
    }
}

if (
    ($null -ne $global:PSProfileConfig -and $null -ne $global:PSProfileConfig['_internal']['GitPathMap'].Keys) -or
    ($null -ne $global:PSProfile -and $null -ne $global:PSProfile['GitPathMap'].Keys)
) {
    Register-ArgumentCompleter -CommandName 'Open-Item' -ParameterName 'Path' -ScriptBlock {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
        $global:PSProfileConfig['_internal']['GitPathMap'].Keys | Where-Object {$_ -like "$wordToComplete*"} | Sort-Object | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}

New-Alias -Name open -Value 'Open-Item' -Scope Global -Option AllScope -Force
