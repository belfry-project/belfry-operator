#!/bin/bash
# Show why the database restore of an AWXRestore failed: the operator hides
# the output of pg_restore (no_log). Starts a pod like the restore's
# management pod (same labels, so the NetworkPolicies let it reach the
# database, and the backup PVC) and runs the same pg_restore with its output.
# Only for failed test runs: it writes to the database of the restored
# instance.
# Usage: debug-restore.sh AWXRESTORE
set -uo pipefail
restore="$1"
backup="$(kubectl -n awx get awxrestore "$restore" -o jsonpath='{.spec.backup_name}')"
instance="$(kubectl -n awx get awxrestore "$restore" -o jsonpath='{.spec.deployment_name}')"
dir="$(kubectl -n awx get awxbackup "$backup" -o jsonpath='{.status.backupDirectory}')"
claim="$(kubectl -n awx get awxbackup "$backup" -o jsonpath='{.status.backupClaim}')"
image="$(kubectl -n awx get statefulset -o jsonpath='{.items[0].spec.template.spec.containers[0].image}')"
secret="$instance-postgres-configuration"
field() { kubectl -n awx get secret "$secret" -o jsonpath="{.data.$1}" | base64 -d; }
echo "Restore $restore of $backup ($claim:$dir) into $instance with $image"
kubectl -n awx apply -f - <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: debug-restore
  namespace: awx
  labels:
    app.kubernetes.io/managed-by: awx-operator
    app.kubernetes.io/part-of: $instance
    app.kubernetes.io/component: db-management
spec:
  containers:
    - name: debug
      image: $image
      command: ["sleep", "infinity"]
      volumeMounts:
        - name: backup
          mountPath: /backups
  volumes:
    - name: backup
      persistentVolumeClaim:
        claimName: $claim
YAML
kubectl -n awx wait pod/debug-restore --for=condition=Ready --timeout=5m
kubectl -n awx exec debug-restore -- ls -la "$dir"
kubectl -n awx exec debug-restore -- bash -c "pg_restore -l '$dir/tower.db' | head -25; pg_restore -l '$dir/tower.db' | grep -v '^;' | awk '{print \$4, \$5}' | sort | uniq -c"
kubectl -n awx exec debug-restore -- env PGPASSWORD="$(field password)" \
  pg_restore --clean --if-exists --no-owner --no-acl -U "$(field username)" -h "$(field host).awx.svc" \
  -d "$(field database)" -p "$(field port)" "$dir/tower.db" 2>&1 | grep -v '^$' | head -80
echo "pg_restore exit code: ${PIPESTATUS[0]}"
kubectl -n awx delete pod debug-restore --wait=false
