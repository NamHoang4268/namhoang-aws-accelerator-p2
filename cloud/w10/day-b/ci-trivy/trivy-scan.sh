#!/bin/bash
# Trivy image scan — chạy trong CI hoặc local để test
# Fail nếu tìm thấy vulnerability HIGH hoặc CRITICAL

IMAGE="${1:-nginx:latest}"

echo "=== Scanning image: $IMAGE ==="

# Cài Trivy nếu chưa có (Ubuntu/WSL)
if ! command -v trivy &> /dev/null; then
  sudo apt-get install -y wget apt-transport-https gnupg lsb-release
  wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
  echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | \
    sudo tee /etc/apt/sources.list.d/trivy.list
  sudo apt-get update && sudo apt-get install -y trivy
fi

# Scan và fail nếu có HIGH/CRITICAL
trivy image \
  --exit-code 1 \
  --severity HIGH,CRITICAL \
  --no-progress \
  "$IMAGE"

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo "=== PASS: No HIGH/CRITICAL vulnerabilities found ==="
else
  echo "=== FAIL: HIGH or CRITICAL vulnerabilities found — blocking deploy ==="
fi

exit $EXIT_CODE
