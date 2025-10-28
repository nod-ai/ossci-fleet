#!/bin/bash
set -euo pipefail

EXIT_CODE=0

# Default values
POD_NAME="interactive-vscode-${USER}-$(date +%s)-$RANDOM"
LOCAL_PORT="8000"
REMOTE_PORT="9000"
# Get the directory where this script resides (absolute path)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_YAML="${SCRIPT_DIR}/vscode-session-temp.yml"
CONFIG_FILE="${SCRIPT_DIR}/config.json"

MODE=${1:-}

if [[ -z "$MODE" || ( "$MODE" != "web" && "$MODE" != "ssh" ) ]]; then
  echo "Usage: $0 <web|ssh>"
  echo "  web : run browser-based VSCode server"
  echo "  ssh : run remote SSH-accessible VSCode environment"
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: config.json not found. Example format:"
    cat <<EOF
{
  "namespace": "my-namespace",
  "pvc": "my-pvc",
  "public_ssh_key_path": "/path/to/id_rsa.pub",
}
EOF
    exit 1
fi

# Read config
NAMESPACE=$(jq -r '.namespace' "$CONFIG_FILE")
PVC_CLAIM_NAME=$(jq -r '.pvc' "$CONFIG_FILE")
PUB_KEY_PATH=$(jq -r '.public_ssh_key_path' "$CONFIG_FILE")

if [[ "$MODE" != "web" && "$MODE" != "ssh" ]]; then
    echo "Error: mode in config.json must be 'web' or 'ssh'"
    exit 1
fi

YAML_TEMPLATE="${SCRIPT_DIR}/vscode-session-${MODE}.yml"

CLEANING_UP=false
cleanup() {
    # Prevent recursive cleanup
    $CLEANING_UP && return
    CLEANING_UP=true

    echo ""
    echo "Cleaning up (exit code: $EXIT_CODE)..."
    trap - SIGINT EXIT

    if kubectl delete pod "$POD_NAME" -n "$NAMESPACE" --grace-period=30 2>/dev/null; then
        echo "Pod deleted successfully."
    else
        echo "Warning: Pod may have already been deleted or does not exist."
    fi

    rm -f "$TEMP_YAML"
    echo "Cleanup complete."
    exit "$EXIT_CODE"
}

# Set up trap to catch SIGINT (Ctrl+C) and EXIT
trap 'EXIT_CODE=$?; cleanup' SIGINT EXIT

# kubectl check
if ! command -v kubectl &>/dev/null; then
    echo "Error: kubectl command not found."
    exit 1
fi
if [ ! -f "$YAML_TEMPLATE" ]; then
    echo "Error: YAML template '$YAML_TEMPLATE' not found."
    exit 1
fi

# Create SSH secret if needed
if [[ "$MODE" == "ssh" ]]; then
    if [[ ! -f "$PUB_KEY_PATH" ]]; then
        echo "Error: SSH public key not found at $PUB_KEY_PATH"
        exit 1
    fi
    TMPDIR=$(mktemp -d)
    cp "$PUB_KEY_PATH" "$TMPDIR/authorized_keys"
    kubectl -n "$NAMESPACE" delete secret vscode-ssh-key --ignore-not-found
    kubectl -n "$NAMESPACE" create secret generic vscode-ssh-key --from-file=authorized_keys="$TMPDIR/authorized_keys"
    rm -rf "$TMPDIR"
    echo "✅ Created/updated SSH key secret in namespace '$NAMESPACE'."
fi

# Render YAML
echo "Preparing YAML from template: $YAML_TEMPLATE"
sed -e "s/{{POD_NAME}}/${POD_NAME}/g" -e "s/{{PVC_CLAIM_NAME}}/${PVC_CLAIM_NAME}/g" "$YAML_TEMPLATE" > "$TEMP_YAML"

echo "Checking if pod '$POD_NAME' exists in namespace '$NAMESPACE'..."
if kubectl get pod "$POD_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "Pod already exists. Deleting..."
    kubectl delete pod "$POD_NAME" -n "$NAMESPACE" --wait
fi

echo "Applying '$TEMP_YAML' in namespace '$NAMESPACE'..."
kubectl apply -f "$TEMP_YAML" -n "$NAMESPACE"

echo "Waiting for pod '$POD_NAME' to be ready..."
kubectl wait pod "$POD_NAME" -n "$NAMESPACE" --for=condition=Ready --timeout=300s

echo "Pod is ready!"
echo "Waiting for service to start..."

if [[ "$MODE" == "web" ]]; then
    # Wait for VSCode web server port 9000
    echo "Waiting for VSCode service on port $REMOTE_PORT..."
    until kubectl exec -n "$NAMESPACE" "$POD_NAME" -- curl -fs http://localhost:$REMOTE_PORT/ >/dev/null 2>&1; do
        echo "VSCode not ready yet, waiting..."
        sleep 10
    done
    echo "VSCode is ready!"
    echo "Starting port-forward from localhost:$LOCAL_PORT to pod:$REMOTE_PORT..."
    echo "Access VSCode in your browser at: http://localhost:$LOCAL_PORT"
    echo "Press Ctrl+C to stop and cleanup."
    kubectl port-forward -n "$NAMESPACE" "$POD_NAME" "$LOCAL_PORT:$REMOTE_PORT"
else
    # Wait for SSH daemon port 22
    echo "Waiting for SSH service on port 22..."
    until kubectl exec -n "$NAMESPACE" "$POD_NAME" -- bash -c "timeout 1 bash -c '</dev/tcp/localhost/22'" 2>/dev/null; do
        echo "SSH not ready yet, waiting..."
        sleep 5
    done
    echo ""
    echo "Starting port-forward (localhost:2222 -> pod:22)..."
    echo "Once active, open VS Code and select:"
    echo "   ➜  'Remote-SSH: Connect to Host...'"
    echo "Then enter:"
    echo "   ossci@127.0.0.1:2222  "
    echo ""
    echo "Your SSH public key has already been added to the pod."
    echo "Press Ctrl+C to stop and clean up."
    echo ""
    kubectl port-forward -n "$NAMESPACE" "$POD_NAME" 2222:22
fi
