# W10 Day A — RBAC

## Cấu trúc 3 roles

| Role        | Scope                      | Permissions                                                                |
| ----------- | -------------------------- | -------------------------------------------------------------------------- |
| `developer` | Namespace `app-dev`        | get/list/watch/create/update pods, deployments, services, configmaps       |
| `sre`       | ClusterRole (toàn cluster) | get/list/watch/delete pods, deployments, nodes, events + patch deployments |
| `viewer`    | ClusterRole (toàn cluster) | get/list/watch only — không thay đổi gì                                    |

## Apply

```bash
kubectl apply -f namespace.yaml
kubectl apply -f roles.yaml
kubectl apply -f service-accounts.yaml
kubectl apply -f bindings.yaml
```

## Verify bằng kubectl auth can-i

```bash
# Kiểm tra developer có tạo được deployment trong app-dev không
kubectl auth can-i create deployments --namespace app-dev \
  --as=system:serviceaccount:app-dev:sa-developer

# Kiểm tra developer có xóa được pods trong app-prod không (phải là no)
kubectl auth can-i delete pods --namespace app-prod \
  --as=system:serviceaccount:app-dev:sa-developer

# Kiểm tra viewer có xóa được pods không (phải là no)
kubectl auth can-i delete pods \
  --as=system:serviceaccount:default:sa-viewer

# Kiểm tra sre có xóa được pods không (phải là yes)
kubectl auth can-i delete pods \
  --as=system:serviceaccount:kube-system:sa-sre
```
