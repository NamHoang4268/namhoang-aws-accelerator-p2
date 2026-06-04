#!/bin/bash
# Called by Terraform external data source to retrieve K8s service account token
# Inputs (via stdin as JSON): host, private_key path

set -euo pipefail

# Parse JSON input from Terraform
eval "$(cat /dev/stdin | python3 -c "
import json, sys
data = json.load(sys.stdin)
for k, v in data.items():
    print(f'{k}=\"{v}\"')
")"

# SSH options — strict host checking off for lab (EC2 fresh instance)
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10 -i ${private_key}"

# Retrieve the service account token from minikube cluster
TOKEN=$(ssh $SSH_OPTS ubuntu@${host} \
  "KUBECONFIG=/home/ubuntu/.kube/config kubectl get secret terraform-admin-token \
    -n kube-system \
    -o jsonpath='{.data.token}' | base64 -d" 2>/dev/null)

# Output as JSON for Terraform external data source
echo "{\"token\": \"${TOKEN}\"}"
