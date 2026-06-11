# W9 Lab — GitOps-ify cụm (Day A + Day B + Day C)

Bài lab này xây dựng theo từng phần, tương ứng từng ngày của tuần W9.

## Cấu trúc

```
lab/
├── README.md                    # file này — tổng quan và tiến độ
├── gitops/                      # Day A — GitOps với ArgoCD
│   ├── k8s/                     # Kubernetes manifests (nguồn sự thật)
│   │   ├── namespace.yaml       # wave -1: tạo namespace demo
│   │   ├── web.yaml             # wave 0,1,2: ConfigMap + Deployment + Service
│   ├── argocd/
│   │   ├── apps/
│   │   │   └── web.yaml         # ArgoCD Application cho app web
│   │   └── root.yaml            # Root Application (app-of-apps)
│   └── .github/
│       └── workflows/
│           └── validate.yml     # CI: validate manifest khi có PR
```

## Tiến độ

- [x] Day A — GitOps: ArgoCD, app-of-apps, sync waves, CI validate
- [ ] Day B — Observability: Prometheus, Grafana, Loki, Alert rules
- [ ] Day C — Progressive Delivery: Argo Rollouts, Canary, AnalysisTemplate

## Prerequisite

- Docker đang chạy
- `minikube` đã cài
- `kubectl` đã cài
- `git` đã cài
- Có 1 repo GitHub trống (đặt tên `gitops`)

---

# Day A — GitOps

## Lab 0 — Tạo cụm + repo

```bash
# 1. Tạo cụm local với driver docker
minikube start -p w9 --driver=docker
kubectl config use-context w9
kubectl get nodes   # STATUS phải là Ready

# 2. Clone repo này về local (hoặc tạo repo mới)
# Nếu dùng repo mới:
mkdir gitops && cd gitops
git init
git branch -M main
git remote add origin https://github.com/<ban>/gitops.git
```

Xong khi: node `w9` ở trạng thái Ready.

---

## Lab 1 — Cài ArgoCD vào cụm

```bash
kubectl create ns argocd

# --server-side cần thiết vì CRD của ArgoCD lớn hơn 256KB
# kubectl apply thông thường lưu config vào annotation, bị vượt giới hạn
kubectl apply --server-side -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Đợi ArgoCD sẵn sàng
kubectl -n argocd rollout status deploy/argocd-server
kubectl -n argocd get pods   # tất cả argocd-* phải Running

# Lấy password admin mặc định
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo

# Mở UI (optional)
kubectl -n argocd port-forward svc/argocd-server 8080:443 &
# Truy cập: https://localhost:8080 — login: admin / <password vừa lấy>
```

Xong khi: tất cả pod `argocd-*` ở trạng thái Running.

---

## Lab 2 — Tạo Application → ArgoCD tự sync

Apply Application bằng tay (lần duy nhất dùng kubectl tạo app):

```bash
# Sửa repoURL trong file argocd/apps/web.yaml trước
# Thay <ban> bằng username GitHub của bạn
kubectl apply -f gitops/argocd/apps/web.yaml

# Verify
kubectl -n argocd get app web     # Synced / Healthy
kubectl -n demo get deploy,pod    # 2 pod web đang Running
```

ArgoCD đọc `k8s/` từ Git và tự apply vào cluster. Bạn không chạy `kubectl apply` cho app web.

Xong khi: app `web` = Synced/Healthy trong ArgoCD, 2 pod Running trong namespace `demo`.

---

## Lab 3 — GitOps Loop + Self-heal

```bash
# Test GitOps loop: sửa replicas qua Git, không kubectl
# Mở gitops/k8s/web.yaml, đổi replicas: 2 → 4
git commit -am "scale web 2->4"
git push
# Đợi ~3 phút (polling) hoặc Refresh trong ArgoCD UI
kubectl -n demo get deploy web   # DESIRED phải là 4

# Test self-heal: sửa tay trên cluster
kubectl -n demo scale deploy/web --replicas=9
kubectl -n demo get deploy web -w
# Vài giây sau ArgoCD phát hiện drift và kéo về 4 (theo Git)
```

Điều cần thấy: sửa tay không tồn tại được. Cluster luôn về trạng thái Git định nghĩa.

---

## Lab 4 — Rollback bằng git revert

```bash
git revert HEAD --no-edit && git push
# ArgoCD sync cụm về trạng thái commit cũ

# Verify rollback thật sự
kubectl -n demo get deploy web   # replicas về 2
```

Điểm quan trọng: `kubectl rollout undo` không hoạt động trong GitOps vì ArgoCD
self-heal sẽ overwrite lại sau vài phút. Rollback đúng cách là `git revert`.

---

## Lab 5 — App-of-Apps

Apply root Application — lần cuối dùng kubectl tạo app:

```bash
# Sửa repoURL trong gitops/argocd/root.yaml trước
git add gitops/argocd/root.yaml && git commit -m "app-of-apps root"
git push

kubectl apply -f gitops/argocd/root.yaml

# Verify
kubectl -n argocd get applications   # phải thấy: root + web
```

Từ đây để thêm app mới: chỉ cần thêm file vào `argocd/apps/` và push. Root tự phát hiện và tạo Application con. Không cần `kubectl apply` nữa.

---

## Lab 6 — Sync Waves

Sync waves đã được cấu hình sẵn trong `k8s/namespace.yaml` và `k8s/web.yaml`:

```
Namespace (wave -1) → ConfigMap (wave 0) → Deployment (wave 1) → Service (wave 2)
```

```bash
git add gitops/k8s/ && git commit -m "add namespace + sync waves"
git push
# Quan sát trong ArgoCD UI: tab Sync → thấy resource apply đúng thứ tự
```

Nếu thiếu sync waves: Deployment chạy trước khi ConfigMap tồn tại → pod lỗi
`CreateContainerConfigError`.

---

## Lab 7 — CI: validate manifest khi có PR

```bash
git add gitops/.github/ && git commit -m "add CI validate workflow"
git push
```

Sau đó vào GitHub Settings → Branches → Add rule cho `main`:

- Require a pull request before merging
- Require status checks to pass → chọn `validate`

Thử: tạo PR với manifest sai schema → job `validate` fail → nút Merge bị khóa.

---

## Kết quả Day A

Cluster đã được GitOps-managed hoàn toàn:

- Git là nguồn sự thật duy nhất
- ArgoCD tự sync mọi thay đổi
- Rollback bằng `git revert`
- App-of-apps: thêm app mới chỉ cần thêm file + push
- Sync waves đảm bảo thứ tự deploy đúng
- CI validate manifest trước khi merge
