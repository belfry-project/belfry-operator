#!/bin/bash
# Check that the managed database of an AWX instance runs the given PostgreSQL
# major version, that the instance's database secret points to it, and that no
# PostgreSQL StatefulSet of another version is left for the instance.
# Usage: check-postgres.sh INSTANCE VERSION  (e.g. check-postgres.sh awx 18)
set -euo pipefail
instance="$1"
version="$2"
statefulset="$instance-postgres-$version"
kubectl -n awx rollout status "statefulset/$statefulset" --timeout=10m
server="$(kubectl -n awx exec "$statefulset-0" -c postgres -- psql -tAc 'SHOW server_version')"
echo "$statefulset-0 runs PostgreSQL $server"
if [ "${server%%.*}" != "$version" ]; then
  echo "Expected PostgreSQL $version in $statefulset-0" >&2
  exit 1
fi
# The operator sets the status fields one after the other at the end of a
# reconciliation
"$(dirname "$0")/wait-for-status.sh" awx "$instance" postgresConfigurationSecret > /dev/null
secret="$(kubectl -n awx get awx "$instance" -o jsonpath='{.status.postgresConfigurationSecret}')"
host="$(kubectl -n awx get secret "$secret" -o jsonpath='{.data.host}' | base64 -d)"
echo "Secret $secret points to $host"
if [ "$host" != "$statefulset" ]; then
  echo "Expected the database host $statefulset in $secret" >&2
  exit 1
fi
others="$(kubectl -n awx get statefulsets -o name | grep -E "^statefulset.apps/$instance-postgres(-[0-9]+)?$" | grep -vx "statefulset.apps/$statefulset" || true)"
if [ -n "$others" ]; then
  echo "Old PostgreSQL StatefulSets of $instance are left: $others" >&2
  exit 1
fi
