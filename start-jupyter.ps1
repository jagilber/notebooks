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
    jupyter lab

}

function install-jupyter(){
    write-host 'installing jupyter' -ForegroundColor Green
    (pip) | out-null

    if ($error) {
        write-error 'pip not found. install latest python and check %path%'
        return $false
    }


    pip install jupyter
    pip install jupyterlab
    dotnet tool install --global dotnet-try
    dotnet try jupyter install
    return $true
}

main