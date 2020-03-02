<#
https://www.hanselman.com/blog/AnnouncingNETJupyterNotebooks.aspx
#>

param(

)

function main() {

    $error.Clear()
    if (!$env:Path.Contains($pwd)) {
        $env:Path += ";$pwd"
    }

    (jupyter) | out-null

    if ($error) {
        if(!(install-jupyter)) {
            return $false
        }
    }


    jupyter kernelspec list
    jupyter --paths

    write-host 'starting jupyter' -ForegroundColor Green
    start jupyter lab

}

function install-jupyter(){
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if(!$isAdmin){
        Write-Warning "restart script as administrator"
        return $false
    }

    write-host 'installing jupyter' -ForegroundColor Green
    $error.Clear()
    (pip) | out-null

    if ($error) {
        write-error 'pip not found. install latest python and check %path% https://www.python.org/downloads/'
        return $false
    }


    pip install jupyter
    pip install jupyterlab
    dotnet tool install --global Microsoft.dotnet-interactive
    dotnet tool install --global dotnet-try
    dotnet try jupyter install
    return $true
}

main