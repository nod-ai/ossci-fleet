#!/bin/bash
#
# Restores port-forwarding to an existing pod. If `kubectl port-forward` command
# is still running, kills it and reruns it. Else, constructs a `kubectl port-forward`
# command for an existing pod listed by `kubectl get pods`.

set -euo pipefail

pattern="kubectl port-forward"

ps_entry="$(ps a | (grep -F "${pattern}" || true) | (grep -v grep || true))"

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

get_pods_entry="$(kubectl get pods -n "$NAMESPACE" | (grep "\binteractive-vscode-${USER}\b" || true))"

if [[ -z "$get_pods_entry" ]]
then
  echo "No running pod."
  exit 1
fi
  
echo "Found running pod: $get_pods_entry"
pod_name="$(echo "$get_pods_entry" | grep -o '^[^[:space:]]\+')"
echo "Pod name: $pod_name"
command="kubectl port-forward -n $NAMESPACE $pod_name 2222:22"
echo "Executing: $command"
$command
exit 0
