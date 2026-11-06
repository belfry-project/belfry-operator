#!/bin/bash
# Print the admin password of an AWX instance, from the secret named in its
# status. Usage: admin-password.sh [INSTANCE]  (defaults to awx)
# A restored instance keeps the old instance's secret names (e.g.
# awx-admin-password), so do not guess <instance>-admin-password.
# The operator sets status.adminPasswordSecret only after the deployment
# finished, so wait for it (up to ADMIN_PASSWORD_TIMEOUT seconds, default 600).
set -euo pipefail
instance="${1:-awx}"
deadline=$((SECONDS + ${ADMIN_PASSWORD_TIMEOUT:-600}))
while true; do
  secret="$(kubectl -n awx get awx "$instance" -o jsonpath='{.status.adminPasswordSecret}' 2>/dev/null || true)"
  if [ -n "$secret" ]; then
    password="$(kubectl -n awx get secret "$secret" -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)"
    if [ -n "$password" ]; then
      printf '%s\n' "$password"
      exit 0
    fi
  fi
  if [ $SECONDS -ge $deadline ]; then
    echo "awx/$instance has no usable admin password after ${ADMIN_PASSWORD_TIMEOUT:-600}s (status.adminPasswordSecret='${secret}')" >&2
    exit 1
  fi
  sleep 10
done
