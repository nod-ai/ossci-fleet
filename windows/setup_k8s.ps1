# This is a simple setup script that ensures prereqs for running k8s jobs on the OSSCI
# cluster are met.

$ErrorActionPreference = "Stop"

$kubectlVersion = "v1.32.0"

Write-Host "Starting kubernetes setup..."

# Exit early if KUBECONFIG is not set to a valid path
$kubeconfigPath = [System.Environment]::GetEnvironmentVariable('KUBECONFIG')
if ( -not $kubeconfigPath) {
    Write-Host "KUBECONFIG is not set or empty. Exiting"
    Write-Host "Please download the authentication file from the AMD OSSCI confluence site and set KUBECONFIG env variable to the file path"
    Write-Host "You will need this auth file to access the k8s cluster"
    exit 1
}
elseif ( -not (Test-Path -Path $kubeconfigPath)) {
    Write-Host "File $kubeconfigPath does not exit. Exiting"
    Write-Host "Plese make sure the KUBECONFIG env variable is correctly set to the authentication file path"
    exit 1
}
else {
    Write-Host "KUBECONFIG is set to: $kubeconfigPath"
}

Write-Host "Downloading kubectl..."
curl.exe -LO "https://dl.k8s.io/release/$kubectlVersion/bin/windows/amd64/kubectl.exe"

Write-Host "Downloading kubectl checksum..."
curl.exe -LO "https://dl.k8s.io/$kubectlVersion/bin/windows/amd64/kubectl.exe.sha256"

Write-Host "Verifying the kubectl binary..."
$calculatedHash = (Get-FileHash -Algorithm SHA256 .\kubectl.exe).Hash
$expectedHash = Get-Content .\kubectl.exe.sha256

if ($calculatedHash -eq $expectedHash) {
    Write-Host "Checksum verification succeeded."
} else {
    Write-Host "Checksum verification failed! Exiting."
    exit 1
}

# Requires elevated powershell
# Check if the current directory is already present in PATH
$path = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine)

if ($path -split ';' -contains $PWD) {
    Write-Host "The current directory $PWD is already in the PATH."
} else {
    Write-Host "The current directory $PWD is not in the PATH. Adding..."
    
    [System.Environment]::SetEnvironmentVariable(
        "Path",
        $path + ";$PWD", 
        [System.EnvironmentVariableTarget]::Machine
    )

    # Also modify the current context
    $env:Path = $path + ";$PWD"
}

Write-Host "Setup completed successfully!"
Write-Host "If you want to run jobs from a different elevated powershell session, make sure to set the KUBECONFIG env variable again."
