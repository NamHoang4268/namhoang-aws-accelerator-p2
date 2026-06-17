# Runbook: ESO Secret Rotation Failure

**Severity:** High  
**Owner:** SRE / Platform  
**Last Updated:** 2026-06-17

---

## Triệu chứng

- `kubectl get externalsecret -n app-dev` hiển thị `STATUS: SecretSyncError`
- App báo lỗi authentication / connection refused sau rotation
- Alert: ESO sync failed

---

## Nguyên nhân thường gặp

| Nguyên nhân             | Dấu hiệu                                     |
| ----------------------- | -------------------------------------------- |
| AWS credentials hết hạn | `SecretSyncError: AccessDenied`              |
| Secret bị xóa trên AWS  | `SecretSyncError: ResourceNotFoundException` |
| Network issue           | `SecretSyncError: connection timeout`        |
| ESO pod không healthy   | ESO pods CrashLoopBackOff                    |

---

## Điều tra

```powershell
# 1. Kiểm tra trạng thái ExternalSecret
kubectl describe externalsecret demo-secret -n app-dev

# 2. Kiểm tra SecretStore
kubectl describe secretstore aws-secretsmanager -n app-dev

# 3. Kiểm tra ESO pods
kubectl get pods -n external-secrets

# 4. Xem ESO logs
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets --tail=50

# 5. Kiểm tra secret còn tồn tại trên AWS
aws secretsmanager describe-secret --secret-id "w10/demo/db-password" --region ap-southeast-1
```

---

## Xử lý

### AWS credentials hết hạn

```powershell
# Tạo access key mới trên AWS Console, sau đó update secret
kubectl create secret generic aws-credentials `
  --from-literal=access-key-id=<NEW_KEY_ID> `
  --from-literal=secret-access-key=<NEW_SECRET_KEY> `
  -n app-dev --dry-run=client -o yaml | kubectl apply -f -

# Force ESO re-sync
kubectl annotate externalsecret demo-secret -n app-dev force-sync=$(date +%s) --overwrite
```

### Secret bị xóa trên AWS

```powershell
# Tạo lại secret trên AWS
aws secretsmanager create-secret `
  --name "w10/demo/db-password" `
  --secret-string "NewPassword123" `
  --region ap-southeast-1

# Force sync
kubectl annotate externalsecret demo-secret -n app-dev force-sync=$(date +%s) --overwrite
```

---

## Verify sau fix

```powershell
kubectl get externalsecret demo-secret -n app-dev
# → STATUS: SecretSynced

kubectl get secret demo-k8s-secret -n app-dev -o jsonpath='{.data.db-password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
# → giá trị mới
```

---

## Post-incident

- [ ] Root cause xác định
- [ ] Credentials rotation policy review
- [ ] Alert cho ESO sync failure đã được set chưa
