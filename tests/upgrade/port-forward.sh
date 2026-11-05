#!/bin/bash
# (Re)start a port-forward to the AWX service on localhost:8080.
set -euo pipefail
pkill -f 'kubectl -n awx port-forward' || true
nohup kubectl -n awx port-forward svc/awx-service 8080:80 > /tmp/port-forward.log 2>&1 &
for _ in $(seq 60); do
  curl -s -o /dev/null http://localhost:8080/api/v2/ping/ && exit 0
  sleep 5
done
echo "AWX API not reachable through the port-forward" >&2
cat /tmp/port-forward.log >&2
exit 1
