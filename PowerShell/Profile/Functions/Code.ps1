function global:code {
    [CmdletBinding(DefaultParameterSetName = 'Location')]
    Param (
        [parameter(Mandatory,Position = 0,ParameterSetName = 'Location')]
        [Alias('l')]
        [String]
        $Location,
        [parameter(ValueFromPipeline,ParameterSetName = 'InputObject')]
        [Object]
        $InputObject,
        [parameter(ValueFromPipeline,ParameterSetName = 'InputObject')]
        [Switch]
        $AsJob,
        [parameter(ValueFromRemainingArguments,ParameterSetName = 'Location')]
        [parameter(ValueFromRemainingArguments,ParameterSetName = 'Cookbook')]
        [Object]
        $Arguments
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
    Begin {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            $collection = New-Object System.Collections.Generic.List[object]
        }
    }
    Process {
        $code = (Get-Command code -All | Where-Object { $_.CommandType -ne 'Function' })[0].Source
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            $collection.Add($InputObject)
        }
        else {
            $target = switch ($PSCmdlet.ParameterSetName) {
                Location {
                    if ($PSBoundParameters['Location'] -eq '.') {
                        $PWD.Path
                    }
                    elseif ($null -ne $global:PSProfileConfig['_internal']['GitPathMap'].Keys) {
                        if ($global:PSProfileConfig['_internal']['GitPathMap'].ContainsKey($PSBoundParameters['Location'])) {
                            $global:PSProfileConfig['_internal']['GitPathMap'][$PSBoundParameters['Location']]
                        }
                        else {
                            $PSBoundParameters['Location']
                        }
                    }
                    else {
                        $PSBoundParameters['Location']
                    }
                }
                Cookbook {
                    [System.IO.Path]::Combine($global:PSProfileConfig['_internal']['GitPathMap']['chef-repo'],'cookbooks',$PSBoundParameters['Cookbook'])
                }
            }
            Write-Verbose "Running command: & `$code $($PSBoundParameters[$PSCmdlet.ParameterSetName]) $Arguments"
            & $code $target $Arguments
        }
    }
    End {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            if ($AsJob) {
                Write-Verbose "Piping input to Code: `$collection | Start-Job {& $code -}"
                $collection | Start-Job { & $code - } -InitializationScript { $code = (Get-Command code -All | Where-Object { $_.CommandType -ne 'Function' })[0].Source }
            }
            else {
                Write-Verbose "Piping input to Code: `$collection | & `$code -"
                $collection | & $code -
            }
        }
    }
}

if ($null -ne $global:PSProfileConfig['_internal']['GitPathMap'].Keys) {
    Register-ArgumentCompleter -CommandName 'code' -ParameterName 'Location' -ScriptBlock {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
        $set = @('.','-')
        $set += $global:PSProfileConfig['_internal']['GitPathMap'].Keys
        $set | Where-Object {$_ -like "*$wordToComplete*"} | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}