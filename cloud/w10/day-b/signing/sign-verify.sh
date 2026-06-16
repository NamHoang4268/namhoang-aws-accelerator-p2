#!/bin/bash
# Cosign v3 — ký và verify container image với keyless signing (OIDC)
# Chạy trên Linux/WSL. Trên Windows dùng cosign-windows-amd64.exe

IMAGE="ttl.sh/namhoang-w10-demo:1h"
DIGEST="sha256:a8fc3c57e10bed4fa9cc11f5c7a6dd4295497e04483cd021d96f7aa4d185cf14"
IMAGE_WITH_DIGEST="${IMAGE}@${DIGEST}"

echo "=== Bước 1: Build image ==="
docker build -t "$IMAGE" -f Dockerfile .

echo "=== Bước 2: Push image lên ttl.sh (public registry tạm, tự xóa sau 1h) ==="
docker push "$IMAGE"
# Lấy digest sau khi push:
# docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE"

echo "=== Bước 3: Ký image với Cosign keyless (OIDC) ==="
# --yes: bỏ qua prompt xác nhận
# Lần đầu chạy sẽ mở browser để đăng nhập Google/GitHub
# Cosign dùng Fulcio CA để cấp certificate tạm thời, log lên Rekor transparency log
cosign sign --yes "$IMAGE_WITH_DIGEST"

echo "=== Bước 4: Verify signature ==="
# --certificate-identity: email dùng để ký (từ OIDC token)
# --certificate-oidc-issuer: provider đã dùng để xác thực
cosign verify \
  --certificate-identity="ngokhoangnam4268@gmail.com" \
  --certificate-oidc-issuer="https://accounts.google.com" \
  "$IMAGE_WITH_DIGEST"

# Output khi verify thành công:
# - "cosign claims were validated"
# - "Existence of the claims in the transparency log was verified offline"
# - "The code-signing certificate was verified using trusted certificate authority certificates"
# → Image chưa bị tamper kể từ khi ký
