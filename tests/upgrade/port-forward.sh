#!/bin/bash
# (Re)start a port-forward to the service of an AWX instance on localhost.
# Usage: port-forward.sh [INSTANCE] [LOCAL_PORT]  (defaults: awx 8080)
set -euo pipefail
instance="${1:-awx}"
port="${2:-8080}"
pkill -f "kubectl -n awx port-forward .* $port:80" || true
nohup kubectl -n awx port-forward "svc/$instance-service" "$port:80" > "/tmp/port-forward-$instance.log" 2>&1 &
for _ in $(seq 60); do
  curl -s -o /dev/null "http://localhost:$port/api/v2/ping/" && exit 0
  sleep 5
done
echo "$instance API not reachable through the port-forward on port $port" >&2
cat "/tmp/port-forward-$instance.log" >&2
exit 1
