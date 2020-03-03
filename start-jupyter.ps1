<#
https://www.hanselman.com/blog/AnnouncingNETJupyterNotebooks.aspx
#>

param(

)

function main() {
    [net.servicePointManager]::Expect100Continue = $true;
    [net.servicePointManager]::SecurityProtocol = [net.SecurityProtocolType]::Tls12;

    $error.Clear()
    if (!$env:Path.Contains($pwd)) {
        $env:Path += ";$pwd"
    }

    if(!(check-pip) -or !(check-dotnet) -or !(check-jupyter)) {
        return $false
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

    write-host 'pip install jupyter' -ForegroundColor Green
    pip install jupyter

    write-host 'pip install jupyterlab' -ForegroundColor Green
    pip install jupyterlab

    write-host 'dotnet tool install --global Microsoft.dotnet-interactive' -ForegroundColor Green
    dotnet tool install --global Microsoft.dotnet-interactive

    write-host 'dotnet tool install --global dotnet-try' -ForegroundColor Green
    dotnet tool install --global dotnet-try

    write-host 'dotnet try jupyter install' -ForegroundColor Green
    dotnet try jupyter install
    return $true
}

function check-dotnet() {
    (dotnet) | out-null

    if ($error) {
        write-warning 'dotnet not found. install latest dotnet sdk from https://dotnet.microsoft.com/download/visual-studio-sdks'
        write-warning 'restart powershell / vscode and restart script'
        start-process 'https://dotnet.microsoft.com/download/visual-studio-sdks'
        return $false
    }
}

function check-jupyter () {
    (jupyter) | out-null

    if ($error) {
        if(!(install-jupyter)) {
            return $false
        }
    }
}

function check-pip() {
    $error.Clear()
    (pip) | out-null

    if ($error) {
        write-warning 'pip not found. install latest python from https://www.python.org/downloads/'
        write-warning 'check / add python dir to %path%'
        write-warning 'restart powershell / vscode and restart script'
        start-process 'https://www.python.org/downloads/'
        return $false
    }
    return $true
}

main