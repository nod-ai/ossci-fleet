# This is a helper script for running k8s jobs.
# If you have a long-running job, you may want to decompose this script
# and wait on the job itself or change the timeout flag mentioned below.
param (
    [string]$JobFile,
    [string]$Namespace
)

$ErrorActionPreference = "Stop"

# Define kubectl path function
function Get-KubectlPath {
    # Check current directory first (where setup_k8s.ps1 likely downloaded it)
    $scriptDir = Split-Path -Parent $PSCommandPath
    $baseDir = Split-Path -Parent $scriptDir
    $currentDirKubectl = Join-Path $baseDir "kubectl.exe"
    
    if (Test-Path $currentDirKubectl) {
        return $currentDirKubectl
    }
    
    # Also check if kubectl is in the same directory as the script
    $scriptDirKubectl = Join-Path $scriptDir "kubectl.exe"
    if (Test-Path $scriptDirKubectl) {
        return $scriptDirKubectl
    }
    
    # Check if kubectl is in PATH
    $kubectlInPath = Get-Command kubectl -ErrorAction SilentlyContinue
    
    if ($kubectlInPath) {
        return "kubectl"
    }
    
    # Common installation locations
    $possiblePaths = @(
        "C:\Program Files\Kubernetes\kubectl.exe",
        "$env:USERPROFILE\.kube\kubectl.exe",
        "$env:ProgramFiles\Docker\Docker\resources\bin\kubectl.exe",
        "$env:LOCALAPPDATA\Programs\kubectl\kubectl.exe"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    Write-Host "Error: kubectl not found. Please install kubectl or specify the full path." -ForegroundColor Red
    Write-Host "You can download kubectl from: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/" -ForegroundColor Yellow
    Write-Host "Note: The setup_k8s.ps1 script may have downloaded kubectl to your current directory. Try running: .\kubectl version" -ForegroundColor Yellow
    exit 1
}

# Get kubectl command/path
$kubectl = Get-KubectlPath

# Check if a YAML file is provided
if (-not $JobFile) {
    Write-Host "Usage: .\script.ps1 <job.yaml> <namespace>"
    exit 1
}

# Check if a Namespace is provided
if (-not $Namespace) {
    Write-Host "Usage: .\script.ps1 <job.yaml> <namespace>"
    exit 1
}

# Check if Job file exists
if (-not (Test-Path $JobFile)) {
    Write-Host "Error: Job file '$JobFile' not found."
    exit 1
}

# Apply the job
Write-Host "Deploying the Job in namespace '$Namespace'..."
$output = & $kubectl apply -f $JobFile -n $Namespace
if (-not $?) {
    Write-Host "Error deploying the Job."
    exit 1
}

# Extract the job name from the output
if ($output -match "job\.batch/([^ ]+)") {
    $JobName = $matches[1]
} else {
    Write-Host "Error: Could not extract Job name from the apply output."
    exit 1
}

Write-Host "Job name: $JobName"

# Wait for the job to complete. Change timeout if your job is expected to exceed 25 mins.
Write-Host "Waiting for the Job to complete in namespace '$Namespace'..."
& $kubectl wait job/$JobName -n $Namespace --for condition=complete --timeout=1500s
if (-not $?) {
    Write-Host "Error: Job did not complete successfully."
    exit 1
}

# Fetch logs from the job
Write-Host "Fetching logs from namespace '$Namespace'..."
& $kubectl logs job/$JobName -n $Namespace
if (-not $?) {
    Write-Host "Error: Failed to fetch logs from the Job."
    exit 1
}

# Delete the job
Write-Host "Deleting the Job in namespace '$Namespace'..."
& $kubectl delete job/$JobName -n $Namespace
if (-not $?) {
    Write-Host "Error: Failed to delete the Job."
    exit 1
}

Write-Host "Job execution completed successfully in '$Namespace' namespace."
