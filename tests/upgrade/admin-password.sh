#!/bin/bash
# Print the admin password of an AWX instance, from the secret named in its
# status. Usage: admin-password.sh [INSTANCE]  (defaults to awx)
# A restored instance keeps the old instance's secret names (e.g.
# awx-admin-password), so do not guess <instance>-admin-password.
set -euo pipefail
instance="${1:-awx}"
secret="$(kubectl -n awx get awx "$instance" -o jsonpath='{.status.adminPasswordSecret}')"
if [ -z "$secret" ]; then
  echo "awx/$instance has no status.adminPasswordSecret yet" >&2
  exit 1
fi
password="$(kubectl -n awx get secret "$secret" -o jsonpath='{.data.password}' | base64 -d)"
if [ -z "$password" ]; then
  echo "Secret $secret has no password" >&2
  exit 1
fi
printf '%s\n' "$password"
