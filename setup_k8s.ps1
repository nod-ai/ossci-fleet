# kubectl-install.ps1

# This is a simple setup script that ensures prereqs for running k8s jobs on the OSSCI
# cluster are met.

$kubectlVersion = "v1.32.0"

Write-Host "Starting kubernetes setup..."

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
Write-Host "Adding current directory to PATH..."
[System.Environment]::SetEnvironmentVariable(
    "Path",
    [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine) + ";$PWD",
    [System.EnvironmentVariableTarget]::Machine
)

Write-Host "Setup completed successfully!"
