#!/bin/bash

set -e

CLUSTER_NAME="iot-cluster"

echo "==> Creating K3d cluster: $CLUSTER_NAME..."

# Check if cluster already exists
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "Cluster $CLUSTER_NAME already exists. Deleting..."
    k3d cluster delete $CLUSTER_NAME
fi

# Create K3d cluster with port mapping for services
k3d cluster create $CLUSTER_NAME \
    --port 8080:80@loadbalancer \
    --agents 1 \
    --wait

echo "==> Cluster created successfully!"

# Wait for cluster to be ready
echo "==> Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=90s

echo "==> Cluster is ready!"
echo ""
kubectl cluster-info
echo ""
kubectl get nodes
