# This is a helper script for running k8s jobs.
# If you have a long-running job, you may want to decompose this script
# and wait on the job itself or change the timeout flag mentioned below.

param (
    [string]$JobFile
)

$ErrorActionPreference = "Stop"

# Check if a YAML file is provided
if (-not $JobFile) {
    Write-Host "Usage: .\script.ps1 <job.yaml>"
    exit 1
}

$Namespace = "dev"

# Apply the job
Write-Host "Deploying the Job in namespace '$Namespace'..."
$output = kubectl apply -f $JobFile -n $Namespace
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
kubectl wait job/$JobName -n $Namespace --for condition=complete --timeout=1500s
if (-not $?) {
    Write-Host "Error: Job did not complete successfully."
    exit 1
}

# Fetch logs from the job
Write-Host "Fetching logs from namespace '$Namespace'..."
kubectl logs job/$JobName -n $Namespace
if (-not $?) {
    Write-Host "Error: Failed to fetch logs from the Job."
    exit 1
}

# Delete the job
Write-Host "Deleting the Job in namespace '$Namespace'..."
kubectl delete job/$JobName -n $Namespace
if (-not $?) {
    Write-Host "Error: Failed to delete the Job."
    exit 1
}

Write-Host "Job execution completed successfully in '$Namespace' namespace."
