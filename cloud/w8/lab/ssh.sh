#!/bin/bash
# SSH helper for WSL — copies .pem to WSL filesystem where chmod works, then connects
set -e

PEM="./k8s-host.pem"
IP=$(terraform output -raw ec2_public_ip)

# Copy to WSL /tmp where chmod actually works (NTFS ignores chmod)
TMP_PEM=$(mktemp /tmp/k8s-host-XXXX.pem)
cp "$PEM" "$TMP_PEM"
chmod 600 "$TMP_PEM"
trap "rm -f $TMP_PEM" EXIT

echo "→ Connecting to ubuntu@$IP ..."
ssh -i "$TMP_PEM" ubuntu@"$IP"
