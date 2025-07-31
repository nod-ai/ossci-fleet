#!/bin/bash
set -e

# Default values
POD_NAME="interactive-vscode"
LOCAL_PORT="8000"
REMOTE_PORT="9000"
TEMP_YAML="vscode-session-temp.yml"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <namespace> <pvc-claim-name|none>"
    echo "  <namespace>          : Kubernetes namespace to use (required)"
    echo "  <pvc-claim-name|none>: PVC claim name to mount for persistent storage, or 'none' if you don't want a PVC"
    exit 1
fi

NAMESPACE="$1"
PVC_CLAIM_NAME="$2"

# Choose template
if [ "$PVC_CLAIM_NAME" = "none" ]; then
    YAML_TEMPLATE="vscode-session-no-pvc.yml"
else
    YAML_TEMPLATE="vscode-session-pvc.yml"
fi

CLEANING_UP=false

cleanup() {
    # Prevent recursive cleanup calls
    if [ "$CLEANING_UP" = true ]; then
        return
    fi
    CLEANING_UP=true
    trap - SIGINT SIGTERM
    echo ""
    echo "Caught signal, cleaning up..."
    echo "Deleting pod '$POD_NAME' in namespace '$NAMESPACE'..."
    if kubectl delete pod "$POD_NAME" -n "$NAMESPACE" --grace-period=30 2>/dev/null; then
        echo "Pod deleted successfully."
    else
        echo "Warning: Pod may have already been deleted or does not exist."
    fi
    rm -f "$TEMP_YAML"
    echo "Cleanup complete."
    exit 0
}

# Set up trap to catch SIGINT (Ctrl+C) and SIGTERM
trap cleanup SIGINT SIGTERM

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
if [ "$PVC_CLAIM_NAME" = "none" ]; then
    sed "s/{{POD_NAME}}/${POD_NAME}/g" "$YAML_TEMPLATE" > "$TEMP_YAML"
else
    sed -e "s/{{POD_NAME}}/${POD_NAME}/g" -e "s/{{PVC_CLAIM_NAME}}/${PVC_CLAIM_NAME}/g" "$YAML_TEMPLATE" > "$TEMP_YAML"
fi

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
sleep 20

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

cleanup
