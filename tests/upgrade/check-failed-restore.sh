#!/bin/bash
# Check that a restore that fails while restoring the database does not leave
# the database user with CREATEDB (belfry-operator#38). The managed database is
# recreated and restored with CREATEDB granted; the restore role revokes it
# also when the restore fails.
#
# Copies the backup of an AWXBackup to a new directory on its PVC with a
# truncated tower.db, restores that into an existing instance (pg_restore
# fails after the database was recreated), waits for the failure, deletes the
# AWXRestore and checks that the user ends up without CREATEDB.
# The instance's database is lost: run it last.
# Usage: check-failed-restore.sh AWXBACKUP INSTANCE PG_VERSION
set -euo pipefail
backup="$1"
instance="$2"
version="$3"
restore="$instance-failed-restore"
postgres_pod="$instance-postgres-$version-0"
dir="$(kubectl -n awx get awxbackup "$backup" -o jsonpath='{.status.backupDirectory}')"
claim="$(kubectl -n awx get awxbackup "$backup" -o jsonpath='{.status.backupClaim}')"
broken="$dir-truncated"
image="$(kubectl -n awx get statefulset "$instance-postgres-$version" -o jsonpath='{.spec.template.spec.containers[0].image}')"
user="$(kubectl -n awx get secret "$instance-postgres-configuration" -o jsonpath='{.data.username}' | base64 -d)"

createdb() {
  kubectl -n awx exec "$postgres_pod" -c postgres -- \
    psql -tA -v ON_ERROR_STOP=1 -c "SELECT rolcreatedb FROM pg_roles WHERE rolname = '$user'"
}

echo "CREATEDB of $user after the successful restores: $(createdb)"
if [ "$(createdb)" != f ]; then
  echo "$user still has CREATEDB after a successful restore" >&2
  exit 1
fi

echo "Copy $claim:$dir to $broken with a truncated tower.db"
kubectl -n awx apply -f - <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: truncate-backup
  namespace: awx
spec:
  restartPolicy: Never
  containers:
    - name: truncate
      image: $image
      command: ["bash", "-c", "set -e; cp -r '$dir' '$broken'; head -c 4096 '$dir/tower.db' > '$broken/tower.db'; ls -la '$broken'"]
      volumeMounts:
        - name: backup
          mountPath: /backups
  volumes:
    - name: backup
      persistentVolumeClaim:
        claimName: $claim
YAML
kubectl -n awx wait pod/truncate-backup --for=jsonpath='{.status.phase}'=Succeeded --timeout=5m
kubectl -n awx logs truncate-backup
kubectl -n awx delete pod truncate-backup --wait

kubectl -n awx apply -f - <<YAML
apiVersion: awx.ansible.com/v1beta1
kind: AWXRestore
metadata:
  name: $restore
  namespace: awx
spec:
  deployment_name: $instance
  backup_pvc: $claim
  backup_dir: $broken
YAML

echo "Wait for $restore to fail"
deadline=$((SECONDS + 900))
until [ "$(kubectl -n awx get awxrestore "$restore" -o jsonpath='{.status.conditions[?(@.type=="Failure")].status}')" = True ]; do
  if [ $SECONDS -gt $deadline ]; then
    echo "$restore did not fail" >&2
    kubectl -n awx get awxrestore "$restore" -o yaml >&2
    exit 1
  fi
  sleep 10
done
kubectl -n awx get awxrestore "$restore" -o jsonpath='{range .status.conditions[*]}{.type}={.status} ({.reason}) {.message}{"\n"}{end}'
if [ "$(kubectl -n awx get awxrestore "$restore" -o jsonpath='{.status.restoreComplete}')" = true ]; then
  echo "$restore with a truncated tower.db did not fail" >&2
  exit 1
fi

# Stop the retries. A retry that already started ends with the revoke too, so
# wait until CREATEDB is gone and check that it stays gone.
kubectl -n awx delete awxrestore "$restore" --wait
deadline=$((SECONDS + 300))
until [ "$(createdb)" = f ]; do
  if [ $SECONDS -gt $deadline ]; then
    echo "$user still has CREATEDB after the failed restore" >&2
    exit 1
  fi
  sleep 10
done
sleep 60
echo "CREATEDB of $user after the failed restore: $(createdb)"
if [ "$(createdb)" != f ]; then
  echo "$user has CREATEDB again after the failed restore" >&2
  exit 1
fi
