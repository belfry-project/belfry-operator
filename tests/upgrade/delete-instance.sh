#!/bin/bash
# Delete an AWX instance with its secrets and PostgreSQL PVCs, so that the
# runner has room for the next one and a restore must work from the backup
# alone. The operator's finalizer keeps the instance's secrets (it removes
# their ownerReferences), and the PostgreSQL PVCs (of every version) stay too.
# Backup PVCs are not touched.
# Usage: delete-instance.sh INSTANCE
set -euo pipefail
instance="$1"
# A restored instance keeps the old instance's names for some secrets, so take
# them from the status
secrets="$(kubectl -n awx get awx "$instance" -o jsonpath='{.status.adminPasswordSecret} {.status.secretKeySecret} {.status.broadcastWebsocketSecret} {.status.postgresConfigurationSecret}')"
statefulsets="$(kubectl -n awx get statefulsets -o name | grep -E "^statefulset.apps/$instance-postgres(-[0-9]+)?$" || true)"
kubectl -n awx delete awx "$instance" --wait --timeout=10m
# shellcheck disable=SC2086 # word splitting is intended
kubectl -n awx wait --for=delete "deployment/$instance-web" "deployment/$instance-task" $statefulsets --timeout=10m
# shellcheck disable=SC2086
kubectl -n awx delete secret --ignore-not-found $secrets \
  "$instance-postgres-configuration" "$instance-receptor-ca" "$instance-receptor-work-signing"
for pvc in $(kubectl -n awx get pvc -o name | grep -E "^persistentvolumeclaim/postgres-[0-9]+-$instance-postgres-[0-9]+-0$" || true); do
  kubectl -n awx delete "$pvc" --timeout=5m
done
kubectl -n awx get secrets,pvc
