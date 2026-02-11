#!/bin/bash
set -e

# Wait for master to be fully ready
sleep 60

# Get the node token from master
MAX_RETRIES=10
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  NODE_TOKEN=$(ssh -o StrictHostKeyChecking=no ubuntu@${master_ip} 'sudo cat /var/lib/rancher/k3s/server/node-token' 2>/dev/null)
  
  if [ -n "$NODE_TOKEN" ]; then
    break
  fi
  
  echo "Waiting for master node token... Retry $RETRY_COUNT"
  sleep 10
  RETRY_COUNT=$((RETRY_COUNT + 1))
done

# Install K3s agent
curl -sfL https://get.k3s.io | K3S_URL=https://${master_ip}:6443 \
  K3S_TOKEN=$NODE_TOKEN sh -s - agent \
  --node-name ${node_name}

echo "Worker ${node_name} joined cluster successfully!"

