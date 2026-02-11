#!/bin/bash
set -e

# Update system
sudo apt-get update
sudo apt-get install -y curl

# Install K3s master node
if [ "$1" == "master" ]; then
  echo "Installing K3s Master Node..."
  
  # Install K3s with specific options
  curl -sfL https://get.k3s.io | sh -s - server \
    --write-kubeconfig-mode 644 \
    --disable traefik \
    --node-name k3s-master \
    --cluster-init
  
  # Wait for K3s to be ready
  sleep 30
  
  # Get node token for workers
  sudo cat /var/lib/rancher/k3s/server/node-token > /tmp/node-token
  
  # Get kubeconfig
  sudo cat /etc/rancher/k3s/k3s.yaml > /tmp/kubeconfig
  
  echo "K3s Master installed successfully!"
  
# Install K3s worker node
elif [ "$1" == "worker" ]; then
  echo "Installing K3s Worker Node..."
  
  # Wait for master to be ready
  sleep 45
  
  # Join cluster (token and master IP will be passed as parameters)
  curl -sfL https://get.k3s.io | K3S_URL=https://$2:6443 \
    K3S_TOKEN=$3 sh -s - agent \
    --node-name k3s-worker-$4
  
  echo "K3s Worker installed successfully!"
fi

