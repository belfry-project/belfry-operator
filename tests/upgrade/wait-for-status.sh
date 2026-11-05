#!/bin/bash
# Wait until a field in the status of a custom resource has the given value,
# or any value if none is given. Shows the status while waiting. Gives up
# after TIMEOUT seconds (default 900; backups and restores of the test data
# take about a minute).
# Usage: wait-for-status.sh KIND NAME FIELD [VALUE]
#   e.g. wait-for-status.sh awxbackup awx-backup backupDirectory
set -euo pipefail
kind="$1"
name="$2"
field="$3"
value="${4:-}"
deadline=$((SECONDS + ${TIMEOUT:-900}))
last=""
while true; do
  current="$(kubectl -n awx get "$kind" "$name" -o jsonpath="{.status.$field}" 2>/dev/null || true)"
  if [ -n "$current" ] && { [ -z "$value" ] || [ "$current" = "$value" ]; }; then
    echo "$kind/$name: $field=$current"
    exit 0
  fi
  conditions="$(kubectl -n awx get "$kind" "$name" -o jsonpath='{range .status.conditions[*]}{.type}={.status} ({.reason}) {.message}{"\n"}{end}' 2>/dev/null || true)"
  if [ "$conditions" != "$last" ]; then
    echo "$kind/$name conditions:"
    echo "$conditions"
    last="$conditions"
  fi
  if [ $SECONDS -gt $deadline ]; then
    echo "Timed out waiting for $kind/$name status $field${value:+=$value}" >&2
    kubectl -n awx get "$kind" "$name" -o yaml >&2 || true
    exit 1
  fi
  sleep 10
done
