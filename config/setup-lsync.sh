#!/usr/bin/env bash
set -euo pipefail

DEV_USER="${DEV_USER:-root}"
DEV_UID="${DEV_UID:-0}"
DEV_GID="${DEV_GID:-0}"
HOME_DIR="${HOME_DIR:-/home/ossci}"
FAST_DIR="${FAST_DIR:-${HOME_DIR}/fast}"
FAST_PERSIST_DIR="${FAST_PERSIST_DIR:-${HOME_DIR}/fast-persist}"
LSYNCD_CONF_FILE="${LSYNCD_CONF_FILE:-/etc/lsyncd.conf}"

echo "=== Lsyncd Setup ==="
echo "Mirroring ${FAST_PERSIST_DIR} (durable) and ${FAST_DIR} (fast)"
echo "Config file: ${LSYNCD_CONF_FILE}"

apt-get install -y rsync lsyncd > /dev/null 2>&1

# Fix up owenership of fast directory (not recursive, but also it's empty)
chown ${DEV_USER}:${DEV_GID} "${FAST_DIR}"

if [[ ! -d "${FAST_PERSIST_DIR}" ]]; then
  mkdir -p "${FAST_PERSIST_DIR}"
  chown ${DEV_USER}:${DEV_GID} "${FAST_PERSIST_DIR}"
fi

echo "=== Pulling down persistent state ==="
# Note the trailing / is important here.
rsync -a --info=progress2 --human-readable "${FAST_PERSIST_DIR}/" "${FAST_DIR}"

echo "=== Starting lsyncd ==="
lsyncd -logfile "${HOME_DIR}/lsyncd.log" -pidfile /tmp/lsyncd.pid "${LSYNCD_CONF_FILE}"
echo "=== Lsyncd started ==="
