# Runbook: Pod CrashLoopBackOff

**Severity:** Medium
**Owner:** SRE
**Last Updated:** 2026-06-17

---

## Symptom (Triệu chứng)

- Pod status = `CrashLoopBackOff`
- `kubectl get pods` hiển thị RESTARTS > 3
- Alert: pod restart rate cao

## Impact (Ảnh hưởng)

Workload không available. Dev/user không truy cập được service.

## Detection (Phát hiện)

```powershell
kubectl get pods -n <NAMESPACE> | Select-String "CrashLoop"
kubectl describe pod <POD_NAME> -n <NAMESPACE>
```

---

## Nguyên nhân thường gặp

| Nguyên nhân             | Dấu hiệu                                                      |
| ----------------------- | ------------------------------------------------------------- |
| App crash (bug, OOM)    | Exit code 1 hoặc 137 (OOM killed)                             |
| Config/secret sai       | Exit code 1, log "connection refused" hoặc "secret not found" |
| Liveness probe fail     | Log "liveness probe failed"                                   |
| Image không tồn tại     | `ErrImagePull` trước khi crash                                |
| Resource limit quá thấp | Exit code 137, OOMKilled trong describe                       |

---

## Điều tra

```powershell
# 1. Xem trạng thái pod
kubectl get pod <POD_NAME> -n <NAMESPACE>

# 2. Xem events gần nhất
kubectl describe pod <POD_NAME> -n <NAMESPACE>

# 3. Xem logs của lần chạy hiện tại
kubectl logs <POD_NAME> -n <NAMESPACE>

# 4. Xem logs của lần chạy trước (trước khi crash)
kubectl logs <POD_NAME> -n <NAMESPACE> --previous

# 5. Kiểm tra exit code
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'
# 0 = success, 1 = app error, 137 = OOM killed, 143 = SIGTERM
```

---

## Xử lý theo từng nguyên nhân

### App crash (exit code 1)

```powershell
# Xem log chi tiết
kubectl logs <POD_NAME> -n <NAMESPACE> --previous --tail=100

# Nếu là bug → escalate dev team
# Nếu là config sai → kiểm tra ConfigMap/Secret
kubectl get configmap -n <NAMESPACE>
kubectl get secret -n <NAMESPACE>
```

### OOM Killed (exit code 137)

```powershell
# Tăng memory limit tạm thời
kubectl set resources deployment <DEPLOYMENT_NAME> -n <NAMESPACE> --limits=memory=512Mi

# Hoặc edit deployment
kubectl edit deployment <DEPLOYMENT_NAME> -n <NAMESPACE>
```

### Secret không tồn tại

```powershell
# Kiểm tra ESO sync
kubectl get externalsecret -n <NAMESPACE>

# Kiểm tra SecretStore
kubectl get secretstore -n <NAMESPACE>

# Force sync ESO
kubectl annotate externalsecret <ES_NAME> -n <NAMESPACE> force-sync=$(date +%s) --overwrite
```

---

## Escalation

- **15 phút** không xử lý được → notify lead SRE
- **Production pod** → page on-call ngay
- **Liên quan security** (credential leak, unauthorized access) → kích hoạt IR playbook

---

## Post-incident

- [ ] Root cause xác định
- [ ] Fix deployed và verified
- [ ] Alert threshold điều chỉnh nếu cần
- [ ] Runbook cập nhật nếu có bước mới
