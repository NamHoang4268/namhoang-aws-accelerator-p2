# W9 Reflection

## Day A — GitOps & CI/CD

### Những gì đã làm

- Cài **ArgoCD** vào minikube cluster (namespace `argocd`)
- Tạo manifests K8s (Deployment, Service, Namespace) trong `day-a/argocd/`
- Tạo **ArgoCD Application** trỏ vào repo GitHub, path `cloud/w9/day-a/argocd`
- Verify GitOps loop: đổi `replicas: 2 → 3`, commit + push → ArgoCD tự sync, pod thứ 3 xuất hiện mà không cần `kubectl apply` tay
- Tạo **GitHub Actions workflow** `k8s-gitops.yml`: validate manifests khi có PR, log khi merge vào main

### Concepts nắm được

**GitOps là gì?**
Git là nguồn sự thật duy nhất cho trạng thái cluster. Thay vì `kubectl apply` tay, mọi thay đổi đi qua Git commit → ArgoCD detect → auto sync.

```
Cách cũ:   Developer → kubectl apply → Cluster
GitOps:    Developer → git push → ArgoCD → Cluster
```

**ArgoCD hoạt động thế nào?**

- Poll Git repo định kỳ (~3 phút) hoặc webhook
- So sánh desired state (Git) với live state (cluster)
- Nếu lệch → tự sync lại (nếu `syncPolicy: automated`)
- Dashboard UI hiển thị health + sync status của từng resource

**GitHub Actions trong GitOps:**

- PR → validate manifests (không apply) → comment kết quả để review
- Merge to main → trigger notify, ArgoCD tự sync sau đó
- Hai bước tách biệt: CI (kiểm tra) và CD (ArgoCD phụ trách)

### Vấn đề gặp phải

- Port 8080 bị dùng bởi process khác → dùng port 8443 cho `kubectl port-forward`
- CRD ArgoCD quá lớn → cần thêm `--server-side` flag khi apply
- kubeconfig port thay đổi sau mỗi lần restart minikube → cần sync lại từ Windows mỗi lần

### Câu hỏi còn mở

- ArgoCD sync theo webhook thay vì poll để real-time hơn thì cấu hình thế nào?
- Khi nhiều team cùng dùng 1 ArgoCD cluster, phân quyền theo namespace thế nào (RBAC)?
- `ApplicationSet` trong ArgoCD dùng khi nào so với `Application` đơn lẻ?

## Day B — Observability: SLO/SLI/OTel

_(sẽ cập nhật sau khi hoàn thành)_

## Day C — Progressive Delivery (Canary)

_(sẽ cập nhật sau khi hoàn thành)_
