# This is a simple setup script that ensures prereqs for running k8s jobs on the OSSCI
# cluster are met.

$ErrorActionPreference = "Stop"

$kubectlVersion = "v1.32.0"

Write-Host "Starting kubernetes setup..."

if (-not (Test-Path -Path "anon.conf" -PathType Leaf)) {
    Write-Host "Please download anon.conf from the AMD OSSCI confluence site to get started"
    Write-Host "You will need this auth file to access the k8s cluster"
    exit 1
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

Write-Host "Adding current directory to PATH (user level)..."
[System.Environment]::SetEnvironmentVariable(
    "Path",
    [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User) + ";$PWD",
    [System.EnvironmentVariableTarget]::User
)

Write-Host "Setup completed successfully!"
