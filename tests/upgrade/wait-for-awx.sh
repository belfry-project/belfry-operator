#!/bin/bash
# Wait until the AWX web and task deployments run the given image and are ready.
set -euo pipefail
image="$1"
deadline=$((SECONDS + 1800))
for deployment in awx-web awx-task; do
  # Check the AWX container itself; the deployments also contain redis and rsyslog
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
echo "AWX runs $image"
