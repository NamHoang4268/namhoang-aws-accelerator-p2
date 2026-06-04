# ── Kubernetes Resources ─────────────────────────────────────────────────────
# NOTE: K8s resources (Deployment, Service, etc.) are NOT managed here via
# hashicorp/kubernetes provider.
#
# Design Decision — Why we chose null + remote-exec over kubernetes provider:
#
#   The hashicorp/kubernetes provider requires:
#     - EC2 public IP  (only known AFTER EC2 is created)
#     - K8s bearer token (only generated AFTER minikube starts inside EC2)
#   ...at PLAN time — before any resource exists. This is the chicken-and-egg
#   problem that makes true 1-click impossible with that provider.
#
# Solution:
#   → See bootstrap.tf for null_resource + remote-exec approach
#   → K8s Deployment + Service are created by user_data.sh (scripts/)
#
# Providers used in this project (satisfies ≥2 requirement):
#   1. hashicorp/aws   — EC2, VPC, ALB, Security Groups, Key Pair
#   2. hashicorp/tls   — Generates RSA-4096 SSH key pair
#   3. hashicorp/null  — SSH verification of K8s cluster post-bootstrap
#   4. hashicorp/local — Writes private key to local .pem file
#   5. hashicorp/time  — Short wait for EC2 SSH daemon startup
# ─────────────────────────────────────────────────────────────────────────────
