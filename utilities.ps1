<#
Checks changes to be committed:

#>
[cmdletbinding()]
param(
    [switch]$useArm = $false
)

function connect-arm() {
    $error.clear()
    if (!(get-command get-azcontext)) {
        set-executionPolicy -executionPolicy Bypass
        install-module az.accounts
    }

    if (!(get-azcontext)) {
        $error.clear()
        import-module az.accounts
        connect-azaccount
    }

    if ($error) {
        $error
    }
    else {
        write-host (get-azcontext | fl * | out-string)
        'connected'
    }
}


function clean-files() {
    param(
        $filesPattern = "-pr.ipynb",
        $filesExcludePattern = "",
        $stringToClean = ""
    )

    $filesToCheck = [io.directory]::GetFiles($pwd, '*.*', [IO.SearchOption]::AllDirectories)

    foreach ($file in $filesToCheck) {
        write-verbose "enumerated file $file"
        if ([regex]::IsMatch($file, $filesPattern, [text.RegularExpressions.RegexOptions]::IgnoreCase )) {
            if ($filesExcludePattern -and 
                [regex]::IsMatch($file, $filesExcludePattern, [text.RegularExpressions.RegexOptions]::IgnoreCase )) {
                continue
            }

            $fileContent = check-file -file $file
            $fileContent | out-file $file.replace('-pr.', '.')
        }
    }

}

function add-patterns([system.collections.Generic.List[hashtable]]$patterns = $null) {
    if (!$global:patterns) {
        $global:patterns = [system.collections.Generic.List[hashtable]]::new()

        if ($useArm) {
            [void]$global:patterns.Add(@{((Get-AzSubscription).Name -join "|")="{{subscriptionName}}"})
            [void]$global:patterns.Add(@{((Get-AzSubscription).Id -join "|")="{{subscription}}"})
            [void]$global:patterns.Add(@{((Get-AzSubscription).TenantId -join "|")="{{tenant}}"})
            [void]$global:patterns.Add(@{((Get-AzResourceGroup).ResourceGroupName -join "|") = "{{resourceGroupName}}"})
            [void]$global:patterns.Add(@{(((Get-AzResourceGroup).Location | sort -unique) -join "|") = "{{location}}"})

            foreach($resource in (get-azresource | select ResourceType, Name)) {
                [void]$global:patterns.Add(@{ ([regex]::Escape($resource.Name)) = "{{$($resource.ResourceType)}}"})
            }
        }

        [void]$global:patterns.Add(@{'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b.'='{{email}}'})
        [void]$global:patterns.Add(@{$env:COMPUTERNAME = '{{computer}}' })
        [void]$global:patterns.Add(@{$env:USERNAME = '{{user}}' })
        [void]$global:patterns.Add(@{$env:USERDOMAIN = '{{domain}}' })
        [void]$global:patterns.Add(@{'[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}' = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' }) # any guid
        [void]$global:patterns.Add(@{'\b[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b' = 'xxx.xxx.xxx.xxx' }) # any ipv4
        [void]$global:patterns.Add(@{'\b[0-9A-Fa-f]{40}\b' = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' }) # cert thumb
        [void]$global:patterns.Add(@{'\b[0-9A-Fa-f]{32}\b' = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' }) # secret

    }

    foreach($pattern in $patterns) {
        if(!$global:patterns.Exists($pattern)) {
            [void]$global:patterns.Add($pattern)
        }
    }
    return $global:patterns
}

function check-file($file) {
    write-host "checking $file" -ForegroundColor Cyan        
    $fileContent = Get-Content -Raw $file
    return write-clean -fileContent $fileContent
}

function write-clean($fileContent) {
    if(!($fileContent -is [string])) {
        $fileContent = $fileContent | fl * | out-string
    }

    foreach ($pattern in add-patterns) {
        $fileContent = replace-string -inputstring $fileContent -pattern $pattern.Keys[0] -replacement $pattern.Values[0]
    }
    return $fileContent
}

function replace-string($inputstring, $pattern, $replacement) {
    if ([regex]::IsMatch($inputstring, $pattern, [text.RegularExpressions.RegexOptions]::IgnoreCase )) {
        write-verbose "found match $pattern"
        return [regex]::Replace($inputstring, $pattern, $replacement, [text.RegularExpressions.RegexOptions]::IgnoreCase )
    }
    write-verbose "no match $pattern"
    return $inputstring
}

set-alias -Name write-host -Value write-clean -option AllScope -Scope Global

# private info
if ((test-path .\utilities-pr.ps1)) { . .\utilities-pr.ps1 }

if($useArm) {connect-arm}

Set-Location -Path .\temp
