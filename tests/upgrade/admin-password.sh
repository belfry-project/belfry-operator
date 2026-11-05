#!/bin/bash
# Print the admin password of an AWX instance, from the secret named in its
# status. Usage: admin-password.sh [INSTANCE]  (defaults to awx)
set -euo pipefail
instance="${1:-awx}"
secret="$(kubectl -n awx get awx "$instance" -o jsonpath='{.status.adminPasswordSecret}')"
kubectl -n awx get secret "${secret:-$instance-admin-password}" -o jsonpath='{.data.password}' | base64 -d
