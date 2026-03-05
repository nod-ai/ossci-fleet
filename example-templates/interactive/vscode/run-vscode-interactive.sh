#!/bin/bash
set -euo pipefail

EXIT_CODE=0

# Default values
POD_NAME="interactive-vscode-${USER}-$(date +%s)-$RANDOM"
REMOTE_PORT="9000"
# Get the directory where this script resides (absolute path)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_YAML="${SCRIPT_DIR}/vscode-session-temp.yml"

MODE="ssh"
CONFIG_FILE="${SCRIPT_DIR}/config.json"

while [[ $# -gt 0 ]]; do
    case "$1" in
        web|ssh)
            MODE="$1"
            shift
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: config.json not found. Example format:"
    cat <<EOF
{
  "namespace": "my-namespace",
  "pvc": "my-pvc",
  "public_ssh_key_path": "/path/to/id_rsa.pub",
  "image": "ubuntu:24.04"
}
EOF
    exit 1
fi

# Read config (required fields)
NAMESPACE=$(jq -r '.namespace' "$CONFIG_FILE")
PVC_CLAIM_NAME=$(jq -r '.pvc' "$CONFIG_FILE")
PUB_KEY_PATH=$(jq -r '.public_ssh_key_path' "$CONFIG_FILE")

# Read config (optional fields with defaults)
IMAGE=$(jq -r '.image // empty' "$CONFIG_FILE")
IMAGE="${IMAGE:-ghcr.io/nod-ai/ossci-gitops/ossci-dev:main@sha256:4d76f74015ac2345ee17ef182921e00bc8d24feee39e36ae91906e2979e3c93e}"
GPU_LIMIT=$(jq -r '.gpu_limit // "1"' "$CONFIG_FILE")
DEV_USER_NAME=$(jq -r '.dev_user // "root"' "$CONFIG_FILE")
DEV_UID=$(jq -r '.dev_uid // "0"' "$CONFIG_FILE")
DEV_GID=$(jq -r '.dev_gid // "0"' "$CONFIG_FILE")
HOME_DIR=$(jq -r '.home_dir // "/home/ossci"' "$CONFIG_FILE")
LOCAL_SSH_PORT=$(jq -r '.local_ssh_port // "2222"' "$CONFIG_FILE")
LOCAL_WEB_PORT=$(jq -r '.local_web_port // "8000"' "$CONFIG_FILE")

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

    if [[ "$MODE" == "ssh" ]]; then
        kubectl delete secret "ssh-key-${POD_NAME}" -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true
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
    SECRET_NAME="ssh-key-${POD_NAME}"
    kubectl -n "$NAMESPACE" create secret generic "$SECRET_NAME" --from-file=authorized_keys="$TMPDIR/authorized_keys"
    rm -rf "$TMPDIR"
    echo "Created SSH key secret '$SECRET_NAME'."
fi

# Render YAML (use | as delimiter since image URLs contain /)
echo "Preparing YAML from template: $YAML_TEMPLATE"
echo "Using image: $IMAGE"
sed -e "s|{{POD_NAME}}|${POD_NAME}|g" \
    -e "s|{{PVC_CLAIM_NAME}}|${PVC_CLAIM_NAME}|g" \
    -e "s|{{IMAGE}}|${IMAGE}|g" \
    -e "s|{{GPU_LIMIT}}|${GPU_LIMIT}|g" \
    -e "s|{{DEV_USER}}|${DEV_USER_NAME}|g" \
    -e "s|{{DEV_UID}}|${DEV_UID}|g" \
    -e "s|{{DEV_GID}}|${DEV_GID}|g" \
    -e "s|{{HOME_DIR}}|${HOME_DIR}|g" \
    "$YAML_TEMPLATE" > "$TEMP_YAML"

echo "Checking if pod '$POD_NAME' exists in namespace '$NAMESPACE'..."
if kubectl get pod "$POD_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "Pod already exists. Deleting..."
    kubectl delete pod "$POD_NAME" -n "$NAMESPACE" --wait
fi

echo "Applying '$TEMP_YAML' in namespace '$NAMESPACE'..."
kubectl apply -f "$TEMP_YAML" -n "$NAMESPACE"

echo "Waiting for pod '$POD_NAME' to be running..."
kubectl wait pod "$POD_NAME" -n "$NAMESPACE" --for=condition=Ready --timeout=300s

if [[ "$MODE" == "web" ]]; then
    # Start following logs in the background.
    kubectl logs --follow -n "$NAMESPACE" "$POD_NAME" &

    echo "VSCode is ready!"
    echo "Starting port-forward from localhost:$LOCAL_WEB_PORT to pod:$REMOTE_PORT..."
    echo "Access VSCode in your browser at: http://localhost:$LOCAL_WEB_PORT"
    echo "Press Ctrl+C to stop and cleanup."
    kubectl port-forward -n "$NAMESPACE" "$POD_NAME" "$LOCAL_WEB_PORT:$REMOTE_PORT"
else
    # Run SSH setup inside the pod via kubectl exec.
    # Pipes setup-ssh.sh into the pod — no ConfigMap needed.
    echo "Setting up SSH inside the pod..."
    kubectl exec -i -n "$NAMESPACE" "$POD_NAME" -- \
        env DEV_USER="$DEV_USER_NAME" DEV_UID="$DEV_UID" DEV_GID="$DEV_GID" HOME_DIR="$HOME_DIR" \
        bash < "${SCRIPT_DIR}/setup-ssh.sh"

    # Wait for sshd to be listening on port 22
    echo "Waiting for SSH daemon on port 22..."
    until kubectl exec -n "$NAMESPACE" "$POD_NAME" -- bash -c "timeout 1 bash -c '</dev/tcp/localhost/22'" 2>/dev/null; do
        sleep 2
    done

    echo ""
    echo "SSH daemon is ready!"
    echo "Starting port-forward (localhost:$LOCAL_SSH_PORT -> pod:22)..."
    echo "Please make sure your ~/.ssh/config is setup as instructed in README"
    echo "Once active, open VS Code and select:"
    echo "   'Remote-SSH: Connect to Host...'"
    echo "Then choose:"
    echo "   ossci  "
    echo ""
    echo "or directly from your terminal:"
    echo "   ssh ossci"
    echo "Your SSH public key has already been added to the pod."
    echo "Press Ctrl+C to stop and clean up."
    echo ""
    kubectl port-forward -n "$NAMESPACE" "$POD_NAME" "$LOCAL_SSH_PORT:22"
fi
