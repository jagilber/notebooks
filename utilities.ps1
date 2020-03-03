<#
Checks changes to be committed:

#>
[cmdletbinding()]
param(
    [switch]$useArm = $false
)

$global:modifiedFiles = @{}

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

function add-patterns([system.collections.Generic.List[hashtable]]$patterns = $null) {
    if (!$global:patterns) {
        $global:patterns = [collections.arrayList]::new()

        if ($useArm) {
            [void]$global:patterns.Add(@{((Get-AzSubscription).Name -join "|") = "{{subscriptionName}}" })
            [void]$global:patterns.Add(@{((Get-AzSubscription).Id -join "|") = "{{subscription}}" })
            [void]$global:patterns.Add(@{((Get-AzSubscription).TenantId -join "|") = "{{tenant}}" })
            [void]$global:patterns.Add(@{((Get-AzResourceGroup).ResourceGroupName -join "|") = "{{resourceGroupName}}" })
            [void]$global:patterns.Add(@{(((Get-AzResourceGroup).Location | sort -unique) -join "|") = "{{location}}" })

            foreach ($resource in (get-azresource | select ResourceType, Name)) {
                [void]$global:patterns.Add(@{ ([regex]::Escape($resource.Name)) = "{{$($resource.ResourceType)}}" })
            }
        }

        [void]$global:patterns.Add(@{'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b.' = '{{email}}' })
        [void]$global:patterns.Add(@{$env:COMPUTERNAME = '{{computer}}' })
        [void]$global:patterns.Add(@{$env:USERNAME = '{{user}}' })
        [void]$global:patterns.Add(@{$env:USERDOMAIN = '{{domain}}' })
        [void]$global:patterns.Add(@{'[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}' = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' }) # any guid
        [void]$global:patterns.Add(@{'\b[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b' = 'xxx.xxx.xxx.xxx' }) # any ipv4
        [void]$global:patterns.Add(@{'\b[0-9A-Fa-f]{40}\b' = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' }) # cert thumb
        [void]$global:patterns.Add(@{'\b[0-9A-Fa-f]{32}\b' = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' }) # secret

    }

    foreach ($pattern in $patterns) {
        if (!$global:patterns.Exists($pattern)) {
            [void]$global:patterns.Add($pattern)
        }
    }
    return $global:patterns
}

function check-file($file) {
    $fileContent = Get-Content -Raw $file
    $script:foundMatches = 0
    $fileContent = write-clean -fileContent $fileContent
    if ($script:foundMatches) {
        return $fileContent.Trim()
    }

    return $null
}

function clean-files($filesPattern = '\.ipynb', $filesExcludePattern = '-pr\.ipynb', [switch]$overwrite) {
    #function clean-files($filesPattern = '-pr\.ipynb', $filesExcludePattern = '', [switch]$overwrite) {
    $filesToCheck = [io.directory]::GetFiles($psscriptroot, '*.*') #, [IO.SearchOption]::AllDirectories)
    $global:modifiedFiles = @{ }

    foreach ($file in $filesToCheck) {
        $tempFile = "$psscriptroot\temp\$([io.path]::getfileName($file))"
        write-host "enumerated file $file"
        if ([regex]::IsMatch($file, $filesPattern, [text.RegularExpressions.RegexOptions]::IgnoreCase )) {
            if ($filesExcludePattern -and 
                [regex]::IsMatch($file, $filesExcludePattern, [text.RegularExpressions.RegexOptions]::IgnoreCase )) {
                write-host "skipping excluded file $file"
                continue
            }

            
            write-host "checking $file" -ForegroundColor Cyan
            $fileContent = check-file -file $file

            if ($fileContent) {
                $tempFileBefore = "$tempFile-before.json"
                write-host "saving before file $tempFileBefore"
                copy $file $tempFileBefore

                $tempFileAfter = "$tempFile-after.json"
                write-host "saving after file $tempFileAfter"
                $fileContent | out-file $tempFileAfter
            
                [void]$global:modifiedFiles.Add($tempFileBefore, $tempFileAfter)
                if ($overwrite) {
                    write-host "overwriting file $file"
                    $fileContent | out-file $file
                }
            }
        }
    }
    return $fileCompares
}

function git-commit() {
    clean-files -overwrite
    foreach ($fcompare in ($global:modifiedFiles).getenumerator()) {
        write-host "cmd /c fc $($fcompare.key) $($fcompare.value)"
        cmd /c fc $fcompare.key $fcompare.value
    }
    git status
    write-host "run git add --all and git commit after reviewing cleaned files." -foregroundcolor yellow
}

function write-clean($fileContent) {
    if (!($fileContent -is [string])) {
        $fileContent = $fileContent | fl * | out-string
    }

    foreach ($pattern in add-patterns) {
        $fileContent = replace-string -inputstring $fileContent -pattern $pattern.Keys[0] -replacement $pattern.Values[0]
    }
    #return $fileContent
    write-output $fileContent
}

function replace-string($inputstring, $pattern, $replacement) {
    if ([regex]::IsMatch($inputstring, $pattern, [text.RegularExpressions.RegexOptions]::IgnoreCase )) {
        write-verbose "found match $pattern"
        $script:foundMatches++
        return [regex]::Replace($inputstring, $pattern, $replacement, [text.RegularExpressions.RegexOptions]::IgnoreCase )
    }
    write-verbose "no match $pattern"
    return $inputstring
}

function set-aliases([switch]$remove) {
    if (!$remove) {
        # setup alias to redact write-host strings
        set-alias -Name write-host -Value write-clean -option AllScope -Scope Global
        # set-alias -Name write-warning -Value write-clean -option AllScope -Scope Global
        # set-alias -Name write-error -Value write-clean -option AllScope -Scope Global
    }
    else {
        remove-alias -Name write-host -Scope Global -Force
        # remove-alias -Name write-warning -Scope Global -Force
        # remove-alias -Name write-error -Scope Global -Force
    }
}

set-aliases

# private info
if ((test-path .\pr\utilities-pr.ps1)) { . .\pr\utilities-pr.ps1 }

if ($useArm) { connect-arm }

# setup ignored working dir
if (!(test-path .\temp)) {
    mkdir .\temp
}

# use temp dir as it is ignored
set-location -Path .\temp
