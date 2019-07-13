function global:code {
    [CmdletBinding(DefaultParameterSetName = 'Location')]
    Param (
        [parameter(Mandatory,Position = 0,ParameterSetName = 'Location')]
        [String]
        $Location,
        [parameter(ParameterSetName = 'Location')]
        [parameter(ParameterSetName = 'Cookbook')]
        [Alias('add','a')]
        [Switch]
        $AddToWorkspace,
        [parameter(ValueFromPipeline,ParameterSetName = 'InputObject')]
        [Object]
        $InputObject,
        [parameter(ValueFromPipeline,ParameterSetName = 'InputObject')]
        [Alias('l','lang')]
        [String]
        $Language = 'txt',
        [parameter(ValueFromPipeline,ParameterSetName = 'InputObject')]
        [Alias('w')]
        [Switch]
        $Wait,
        [parameter(ValueFromRemainingArguments)]
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
            $extDict = @{
                txt = 'txt'
                powershell = 'ps1'
                csv = 'csv'
                sql = 'sql'
                xml = 'xml'
                json = 'json'
                yml = 'yml'
                csharp = 'cs'
                fsharp = 'fs'
                ruby = 'rb'
                html = 'html'
                css = 'css'
                go = 'go'
                jsonc = 'jsonc'
                javascript = 'js'
                typescript = 'ts'
                less = 'less'
                log = 'log'
                python = 'py'
                razor = 'cshtml'
                markdown = 'md'
            }
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
            if ($AddToWorkspace) {
                Write-Verbose "Running command: code --add $($PSBoundParameters[$PSCmdlet.ParameterSetName]) $Arguments"
                & $code --add $target $Arguments
            }
            else {
                Write-Verbose "Running command: code $($PSBoundParameters[$PSCmdlet.ParameterSetName]) $Arguments"
                & $code $target $Arguments
            }
        }
    }
    End {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            $ext = if ($extDict.ContainsKey($Language)) {
                $extDict[$Language]
            } else {
                $Language
            }
            $in = @{
                StdIn = $collection
                TmpFile = [System.IO.Path]::Combine(([System.IO.Path]::GetTempPath()),"code-stdin-$(-join ((97..(97+25)|%{[char]$_}) | Get-Random -Count 3)).$ext")
            }
            $handler = {
                Param(
                    [hashtable]
                    $in
                )
                try {
                    $code = (Get-Command code -All | Where-Object { $_.CommandType -ne 'Function' })[0].Source
                    $in.StdIn | Set-Content $in.TmpFile -Force
                    & $code $in.TmpFile --wait
                }
                catch {
                    throw
                }
                finally {
                    if (Test-Path $in.TmpFile -ErrorAction SilentlyContinue) {
                        Remove-Item $in.TmpFile -Force
                    }
                }
            }
            if (-not $Wait) {
                Write-Verbose "Piping input to Code: `$in | Start-Job {code -}"
                Start-Job -ScriptBlock $handler -ArgumentList $in
            }
            else {
                Write-Verbose "Piping input to Code: `$in | code -"
                .$handler($in)
            }
        }
    }
}

if ($null -ne $global:PSProfileConfig['_internal']['GitPathMap'].Keys) {
    Register-ArgumentCompleter -CommandName 'code' -ParameterName 'Location' -ScriptBlock {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
        $global:PSProfileConfig['_internal']['GitPathMap'].Keys | Where-Object {$_ -like "$wordToComplete*"} | Sort-Object | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}

Register-ArgumentCompleter -CommandName 'code' -ParameterName 'Language' -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
    'txt','powershell','csv','sql','xml','json','yml','csharp','fsharp','ruby','html','css','go','jsonc','javascript','typescript','less','log','python','razor','markdown' | Sort-Object | Where-Object {$_ -like "$wordToComplete*"} | Sort-Object | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
