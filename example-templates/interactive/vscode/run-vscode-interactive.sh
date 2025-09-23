#!/bin/bash
set -euo pipefail

EXIT_CODE=0

# Default values
POD_NAME="interactive-vscode-$(date +%s)-$RANDOM"
LOCAL_PORT="8000"
REMOTE_PORT="9000"
# Get the directory where this script resides (absolute path)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_YAML="${SCRIPT_DIR}/vscode-session-temp.yml"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <namespace> <pvc-claim-name>"
    echo "  <namespace>          : Kubernetes namespace to use (required)"
    echo "  <pvc-claim-name>: PVC claim name to mount for persistent storage"
    exit 1
fi

NAMESPACE="$1"
PVC_CLAIM_NAME="$2"
YAML_TEMPLATE="${SCRIPT_DIR}/vscode-session-pvc.yml"

CLEANING_UP=false

cleanup() {
    # Prevent recursive cleanup
    $CLEANING_UP && return
    CLEANING_UP=true

    echo ""
    echo "Cleaning up (exit code: $EXIT_CODE)..."
    trap - SIGINT SIGTERM EXIT

    if kubectl delete pod "$POD_NAME" -n "$NAMESPACE" --grace-period=30 2>/dev/null; then
        echo "Pod deleted successfully."
    else
        echo "Warning: Pod may have already been deleted or does not exist."
    fi

    rm -f "$TEMP_YAML"
    echo "Cleanup complete."
    exit "$EXIT_CODE"
}

# Set up trap to catch SIGINT (Ctrl+C), SIGTERM, and EXIT
trap 'EXIT_CODE=$?; cleanup' SIGINT SIGTERM EXIT

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl command not found. Please install kubectl."
    exit 1
fi

if [ ! -f "$YAML_TEMPLATE" ]; then
    echo "Error: YAML template '$YAML_TEMPLATE' not found."
    exit 1
fi

echo "Preparing YAML from template: $YAML_TEMPLATE"

# Render YAML
sed -e "s/{{POD_NAME}}/${POD_NAME}/g" -e "s/{{PVC_CLAIM_NAME}}/${PVC_CLAIM_NAME}/g" "$YAML_TEMPLATE" > "$TEMP_YAML"

# Delete existing pod if needed
echo "Checking if pod '$POD_NAME' exists in namespace '$NAMESPACE'..."
if kubectl get pod "$POD_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "Pod already exists. Deleting..."
    kubectl delete pod "$POD_NAME" -n "$NAMESPACE" --wait
fi

echo "Applying '$TEMP_YAML' in namespace '$NAMESPACE'..."
kubectl apply -f "$TEMP_YAML" -n "$NAMESPACE"

# Wait for pod to be ready
echo "Waiting for pod '$POD_NAME' to be ready..."
if ! kubectl wait pod "$POD_NAME" -n "$NAMESPACE" --for=condition=Ready --timeout=300s; then
    echo "Error: Pod failed to become ready within timeout."
    kubectl delete pod "$POD_NAME" -n "$NAMESPACE" 2>/dev/null || true
    cleanup
fi

echo "Pod is ready!"
echo "Waiting for service to start..."
sleep 15

echo "Starting port-forward from localhost:$LOCAL_PORT to pod:$REMOTE_PORT..."
echo "You can now access VSCode at http://localhost:$LOCAL_PORT"
echo "Press Ctrl+C to stop the session and cleanup."
echo ""

# Run port-forward (this will block until interrupted)
if ! kubectl port-forward -n "$NAMESPACE" "$POD_NAME" "$LOCAL_PORT:$REMOTE_PORT"; then
    EXIT_CODE=$?
    echo "Port forwarding failed with exit code: $EXIT_CODE"

    if kubectl get pod "$POD_NAME" -n "$NAMESPACE" &>/dev/null; then
        echo "Pod still exists but port-forward failed."
        echo "This might indicate the service inside the pod isn't listening on port $REMOTE_PORT yet."
    else
        echo "Pod no longer exists."
    fi
fi
