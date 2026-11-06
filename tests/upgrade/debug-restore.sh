#!/bin/bash
# Show why the database restore of an AWXRestore failed: the operator hides
# the output of pg_restore (no_log). Runs the same pg_restore in the restore's
# management pod, with its output. Only for failed test runs: it writes to the
# database of the restored instance.
# Usage: debug-restore.sh AWXRESTORE
set -uo pipefail
restore="$1"
backup="$(kubectl -n awx get awxrestore "$restore" -o jsonpath='{.spec.backup_name}')"
instance="$(kubectl -n awx get awxrestore "$restore" -o jsonpath='{.spec.deployment_name}')"
dir="$(kubectl -n awx get awxbackup "$backup" -o jsonpath='{.status.backupDirectory}')"
pod="$restore-db-management"
secret="$instance-postgres-configuration"
field() { kubectl -n awx get secret "$secret" -o jsonpath="{.data.$1}" | base64 -d; }
kubectl -n awx exec "$pod" -- ls -la "$dir"
kubectl -n awx exec "$pod" -- bash -c "pg_restore --version; pg_restore -l '$dir/tower.db' | head -30; pg_restore -l '$dir/tower.db' | grep -v '^;' | awk '{print \$4, \$5}' | sort | uniq -c"
kubectl -n awx exec "$pod" -- env PGPASSWORD="$(field password)" \
  pg_restore --clean --if-exists --no-owner --no-acl -U "$(field username)" -h "$(field host).awx.svc" \
  -d "$(field database)" -p "$(field port)" "$dir/tower.db" 2>&1 | tail -60
echo "pg_restore exit code: ${PIPESTATUS[0]}"
