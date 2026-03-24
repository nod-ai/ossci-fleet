#!/bin/bash
set -eu

# Configuration via environment variables (passed by run-vscode-interactive.sh)
DEV_USER="${DEV_USER:-root}"
DEV_UID="${DEV_UID:-0}"
DEV_GID="${DEV_GID:-0}"
HOME_DIR="${HOME_DIR:-/home/ossci}"
SSH_KEY_MOUNT="${SSH_KEY_MOUNT:-/mnt/sshkey}"

echo "=== SSH Setup ==="
echo "User: ${DEV_USER} (UID=${DEV_UID}, GID=${DEV_GID}, home=${HOME_DIR})"

# --- Install openssh-server and sudo ---
echo "Installing openssh-server..."
apt-get update -y > /dev/null 2>&1
apt-get install -y openssh-server sudo > /dev/null 2>&1

# --- Generate SSH host keys if missing ---
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -A
fi

# --- Create user if not present ---
if id "${DEV_USER}" >/dev/null 2>&1; then
    echo "User '${DEV_USER}' already exists."
else
    echo "Creating user '${DEV_USER}'..."
    groupadd -g "${DEV_GID}" "${DEV_USER}" 2>/dev/null || true
    useradd -m -u "${DEV_UID}" -g "${DEV_GID}" -s /bin/bash "${DEV_USER}"
fi

# Non-root users get passwordless sudo and GPU group access
if [[ "${DEV_USER}" != "root" ]]; then
    echo "${DEV_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${DEV_USER}"
    chmod 440 "/etc/sudoers.d/${DEV_USER}"

    for grp in render video; do
        if getent group "${grp}" >/dev/null 2>&1; then
            usermod -aG "${grp}" "${DEV_USER}" 2>/dev/null || true
        fi
    done
fi

# --- Point user's home directory to the PVC mount ---
sed -i "s|^\(${DEV_USER}:[^:]*:[^:]*:[^:]*:[^:]*:\)[^:]*|\1${HOME_DIR}|" /etc/passwd

# --- Fix home directory ownership (non-recursive for speed) ---
chown "${DEV_USER}:${DEV_GID}" "${HOME_DIR}"

# --- Setup SSH authorized keys ---
SSH_DIR="${HOME_DIR}/.ssh"

mkdir -p "${SSH_DIR}"
cp "${SSH_KEY_MOUNT}/authorized_keys" "${SSH_DIR}/authorized_keys"
chmod 700 "${SSH_DIR}"
chmod 600 "${SSH_DIR}/authorized_keys"
chown -R "${DEV_USER}:${DEV_GID}" "${SSH_DIR}"

# --- Copy in LLM key ---
if [[ ! -f "/${HOME_DIR}/.amd-llm-api-token" && -f /mnt/amd-llm-api-token/amd-llm-api-token ]]; then
  cp /mnt/amd-llm-api-token/amd-llm-api-token "${HOME_DIR}/.amd-llm-api-token"
  chmod 600 /home/kdrewnia/.amd-llm-api-token
fi

# --- Configure sshd ---
SSHD_CONFIG="/etc/ssh/sshd_config"
if [ -f "${SSHD_CONFIG}" ]; then
    grep -q "^PubkeyAuthentication yes" "${SSHD_CONFIG}" || echo "PubkeyAuthentication yes" >> "${SSHD_CONFIG}"
    grep -q "^PasswordAuthentication no" "${SSHD_CONFIG}" || echo "PasswordAuthentication no" >> "${SSHD_CONFIG}"
    # Allow root login via SSH key when dev_user is root
    if [[ "${DEV_USER}" == "root" ]]; then
        sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' "${SSHD_CONFIG}"
    fi
fi

# --- Propagate container environment to SSH sessions ---
# sshd sanitizes the environment for security. Dockerfile ENV vars (PATH,
# LD_LIBRARY_PATH, etc.) are available in this process but won't be inherited
# by SSH login sessions. Write them to /etc/profile.d/ so login shells pick
# them up — this is the standard Linux mechanism for system-wide env vars.
SKIP_VARS="^(HOME|USER|LOGNAME|SHELL|TERM|HOSTNAME|PWD|OLDPWD|_|SHLVL|DEV_USER|DEV_UID|DEV_GID|HOME_DIR|SSH_KEY_MOUNT|KUBERNETES_.*|DEBIAN_FRONTEND)="
env | grep -vE "${SKIP_VARS}" | while IFS='=' read -r key value; do
    echo "export ${key}=\"${value}\""
done > /etc/profile.d/container-env.sh

# --- Start sshd (daemonized) ---
mkdir -p /var/run/sshd
echo "Starting sshd..."
/usr/sbin/sshd
echo "sshd started."
