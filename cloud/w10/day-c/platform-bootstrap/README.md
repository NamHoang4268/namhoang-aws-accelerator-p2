# W10 Day C — Platform Bootstrap

> Deploy toàn bộ stack W8→W10 lên fresh cluster trong < 2h từ repo.
> Thứ tự quan trọng: infrastructure → security → delivery → observability → cost guard

---

## Stack Overview

| Layer                | Component                                   | Tuần   | Folder                                |
| -------------------- | ------------------------------------------- | ------ | ------------------------------------- |
| Security — RBAC      | Namespace, Roles, ServiceAccounts, Bindings | W10 D1 | `cloud/w10/day-a/rbac/`               |
| Security — Policy    | Gatekeeper + constraints                    | W10 D1 | `cloud/w10/day-a/policies/`           |
| Security — Secrets   | ESO + SecretStore + ExternalSecret          | W10 D2 | `cloud/w10/day-b/eso/`                |
| Resource Guard       | ResourceQuota + LimitRange                  | W10 D3 | `cloud/w10/day-c/platform-bootstrap/` |
| GitOps               | ArgoCD Applications                         | W9 D1  | `cloud/w9/`                           |
| Observability        | Prometheus + Grafana + OTel                 | W9 D2  | `cloud/w9/`                           |
| Progressive Delivery | Argo Rollouts canary                        | W9 D3  | `cloud/w9/`                           |

---

## Bootstrap Order

### Phase 1 — Cluster Foundation (~10 phút)

```powershell
# 1. Tạo namespaces
kubectl apply -f cloud/w10/day-a/rbac/namespace.yaml

# 2. RBAC — roles, service accounts, bindings
kubectl apply -f cloud/w10/day-a/rbac/roles.yaml
kubectl apply -f cloud/w10/day-a/rbac/service-accounts.yaml
kubectl apply -f cloud/w10/day-a/rbac/bindings.yaml

# 3. Verify RBAC
kubectl auth can-i create deployments --namespace app-dev --as=system:serviceaccount:app-dev:sa-developer
# → yes
kubectl auth can-i delete pods --namespace app-prod --as=system:serviceaccount:app-dev:sa-developer
# → no
```

### Phase 2 — Admission Policy (~15 phút)

```powershell
# 4. Cài Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.17.1/deploy/gatekeeper.yaml

# Đợi Gatekeeper pods running
kubectl get pods -n gatekeeper-system -w

# 5. Apply ConstraintTemplates (đợi 15s trước khi apply Constraints)
kubectl apply -f cloud/w10/day-a/policies/gatekeeper-no-privileged.yaml
kubectl apply -f cloud/w10/day-a/policies/gatekeeper-require-labels.yaml

# 6. Verify constraints active
kubectl get constraints
```

### Phase 3 — Secrets Management (~10 phút)

```powershell
# 7. Cài ESO
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets --namespace external-secrets --create-namespace

# Đợi ESO pods running
kubectl get pods -n external-secrets -w

# 8. Tạo AWS credentials secret (không commit vào Git)
kubectl create secret generic aws-credentials `
  --from-literal=access-key-id=<AWS_ACCESS_KEY_ID> `
  --from-literal=secret-access-key=<AWS_SECRET_ACCESS_KEY> `
  -n app-dev

# 9. Apply SecretStore + ExternalSecret
kubectl apply -f cloud/w10/day-b/eso/secret-store.yaml
kubectl apply -f cloud/w10/day-b/eso/secret.yaml

# 10. Verify ESO sync
kubectl get secretstore aws-secretsmanager -n app-dev
kubectl get externalsecret demo-secret -n app-dev
```

### Phase 4 — Resource Guards (~5 phút)

```powershell
# 11. Apply ResourceQuota + LimitRange
kubectl apply -f cloud/w10/day-c/platform-bootstrap/resource-quota.yaml
kubectl apply -f cloud/w10/day-c/platform-bootstrap/limit-range.yaml

# 12. Verify
kubectl describe resourcequota app-dev-quota -n app-dev
kubectl describe limitrange app-dev-limits -n app-dev
```

---

## Verify End-to-End

```powershell
# RBAC hoạt động
kubectl auth can-i create deployments --namespace app-dev --as=system:serviceaccount:app-dev:sa-developer

# Gatekeeper block pod thiếu labels
kubectl run test-bad --image=nginx --restart=Never -n app-dev
# → Error: Pod missing required labels

# Gatekeeper pass pod đủ labels
kubectl run test-good --image=nginx --restart=Never -n app-dev --labels="app=test,env=dev"
# → pod/test-good created
kubectl delete pod test-good -n app-dev

# ESO đã sync secret
kubectl get secret demo-k8s-secret -n app-dev -o jsonpath='{.data.db-password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# LimitRange inject default resources
kubectl run test-limits --image=nginx --restart=Never -n app-dev --labels="app=test,env=dev"
kubectl get pod test-limits -n app-dev -o jsonpath='{.spec.containers[0].resources}'
kubectl delete pod test-limits -n app-dev
```

---

## Mục tiêu đạt được (W10 End State)

- ✅ 3 roles rõ ràng: `developer` / `sre` / `viewer`
- ✅ 2 Gatekeeper constraints enforce: no-privileged + require-labels
- ✅ ESO rotate secret < 60s no-restart
- ✅ ResourceQuota ngăn namespace dùng quá tài nguyên
- ✅ LimitRange tự động inject default resources cho pod không khai báo
