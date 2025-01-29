#!/bin/bash

# This is a helper script for running k8s jobs.
# If you have a long-running job you may want to decompose this script and
# wait on the job itself. You can use add "set -x" to this script to do so.
# You can also change the timeout flag mentioned below to accomodate for your long-running job.

set -e

JOB_FILE=$1
NAMESPACE=$2

# Check if a yaml file is provided
if [ -z "$JOB_FILE" ]; then
  echo "Usage: $0 <job.yaml> <namespace>"
  exit 1
fi

# Check if a namespace is provided
if [ -z "$NAMESPACE" ]; then
  echo "Usage: $0 <job.yaml> <namespace>"
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

# Wait for the job to complete. Change timeout flag if your job is expected to exceed 25 mins.
echo "Waiting for the Job to complete in namespace '$NAMESPACE'..."
kubectl wait job/$JOB_NAME -n "$NAMESPACE" --for condition=complete --timeout=1500s
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
