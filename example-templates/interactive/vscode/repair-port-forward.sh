#!/bin/bash
set -euo pipefail

pattern="kubectl port-forward"

ps_entry="$(ps a | (grep -F "${pattern}" || :) | (grep -v grep || :))"

if [[ -z "$ps_entry" ]]
then
  echo "No process matches \"$pattern\"."
  exit 1
fi

pid="$(echo $ps_entry | grep -o '^[[:space:]]*[0-9]\+')"
command="$(echo $ps_entry | grep -o 'kubectl.*')"

echo "Killing $pid..."
kill $pid

echo "Rerunning command $command..."
$command
