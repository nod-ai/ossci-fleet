#!/bin/bash

JOB_FILE=$1

# Check if a yaml file is provided
if [ -z "$JOB_FILE" ]; then
  echo "Usage: $0 <job.yaml>"
  exit 1
fi

NAMESPACE="dev"

# Apply the job
echo "Deploying the Job in namespace '$NAMESPACE'..."
output=$(kubectl apply -f "$JOB_FILE" -n "$NAMESPACE")
if [ $? -ne 0 ]; then
  echo "Error deploying the Job."
  exit 1
fi

# Extract the job name from the output
JOB_NAME=$(echo "$output" | grep -oP '(?<=job.batch/)[^ ]+')
if [ -z "$JOB_NAME" ]; then
  echo "Error: Could not extract Job name from the apply output."
  exit 1
fi
echo "Job name: $JOB_NAME"

# Wait for the job to complete
echo "Waiting for the Job to complete in namespace '$NAMESPACE'..."
kubectl wait job/$JOB_NAME -n "$NAMESPACE" --for condition=complete
if [ $? -ne 0 ]; then
  echo "Error: Job did not complete successfully."
  exit 1
fi

# Fetch logs from the job
echo "Fetching logs from namespace '$NAMESPACE'..."
kubectl logs job/$JOB_NAME -n "$NAMESPACE"
if [ $? -ne 0 ]; then
  echo "Error: Failed to fetch logs from the Job."
  exit 1
fi

# Delete the job
echo "Deleting the Job in namespace '$NAMESPACE'..."
kubectl delete job/$JOB_NAME -n "$NAMESPACE"
if [ $? -ne 0 ]; then
  echo "Error: Failed to delete the Job."
  exit 1
fi

echo "Job execution completed successfully in '$NAMESPACE' namespace."
