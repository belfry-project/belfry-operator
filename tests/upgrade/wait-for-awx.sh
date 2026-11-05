#!/bin/bash
# Wait until the web and task deployments of an AWX instance run the given
# image and are ready.
# Usage: wait-for-awx.sh IMAGE [INSTANCE]  (INSTANCE defaults to awx)
set -euo pipefail
image="$1"
instance="${2:-awx}"
deadline=$((SECONDS + 1800))
for deployment in "$instance-web" "$instance-task"; do
  # Check the AWX container itself (named like the deployment); the
  # deployments also contain redis and rsyslog
  until [ "$(kubectl -n awx get deployment "$deployment" -o jsonpath="{.spec.template.spec.containers[?(@.name==\"$deployment\")].image}" 2>/dev/null)" = "$image" ]; do
    if [ $SECONDS -gt $deadline ]; then
      echo "Timed out waiting for $deployment to use $image" >&2
      kubectl -n awx get deployments -o wide >&2 || true
      exit 1
    fi
    sleep 10
  done
  kubectl -n awx rollout status "deployment/$deployment" --timeout=20m
done
echo "$instance runs $image"
