# W10 Day B — External Secrets Operator (ESO)

## Bước 1: Cài ESO vào cluster

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace

# Verify
kubectl get pods -n external-secrets
```

## Bước 2: Tạo secret trong AWS Secrets Manager

```bash
# Tạo secret trên AWS
aws secretsmanager create-secret \
  --name "w10/demo/db-password" \
  --secret-string "MySecurePassword123" \
  --region ap-southeast-1
```

## Bước 3: Tạo K8s Secret chứa AWS credentials

```bash
# Không lưu vào Git — chạy tay một lần
kubectl create secret generic aws-credentials \
  --from-literal=access-key-id=<AWS_ACCESS_KEY_ID> \
  --from-literal=secret-access-key=<AWS_SECRET_ACCESS_KEY> \
  -n app-dev
```

## Bước 4: Apply SecretStore và ExternalSecret

```bash
kubectl apply -f secret-store.yaml
kubectl apply -f secret.yaml
```

## Bước 5: Verify

```bash
# Kiểm tra ExternalSecret đã sync chưa
kubectl get externalsecret demo-secret -n app-dev

# Kiểm tra K8s Secret đã được tạo
kubectl get secret demo-k8s-secret -n app-dev

# Xem nội dung secret (base64 decoded)
kubectl get secret demo-k8s-secret -n app-dev \
  -o jsonpath='{.data.db-password}' | base64 -d
```

## Test rotation

```bash
# Cập nhật secret trên AWS
aws secretsmanager update-secret \
  --secret-id "w10/demo/db-password" \
  --secret-string "NewRotatedPassword456" \
  --region ap-southeast-1

# Đợi refreshInterval (1 phút) rồi check lại
kubectl get secret demo-k8s-secret -n app-dev \
  -o jsonpath='{.data.db-password}' | base64 -d
```
