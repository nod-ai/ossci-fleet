#!/bin/bash
set -euo pipefail

pattern="kubectl port-forward"

ps_entry="$(ps a | (grep -F "${pattern}" || :) | (grep -v grep || :))"

if [[ -n "$ps_entry" ]]
then
  echo "Found existing process: $ps_entry"
  pid="$(echo "$ps_entry" | grep -o '^[[:space:]]*[0-9]\+')"
  command="$(echo "$ps_entry" | grep -o 'kubectl.*')"
  echo "Killing $pid..."
  kill $pid
  echo "Rerunning command $command..."
  $command
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.json"
NAMESPACE=$(jq -r '.namespace' "$CONFIG_FILE")

get_pods_entry="$(kubectl get pods -n "$NAMESPACE" | (grep "\bRunning\b" || :))"

if [[ -n "$get_pods_entry" ]]
then
  echo "Found running pod: $get_pods_entry"
  pod_name="$(echo "$get_pods_entry" | grep -o '^[^[:space:]]\+')"
  echo "Pod name: $pod_name"
  command="kubectl port-forward -n $NAMESPACE $pod_name 2222:22"
  echo "Executing: $command"
  $command
  exit 0
fi

echo "No running pod."
exit 1
