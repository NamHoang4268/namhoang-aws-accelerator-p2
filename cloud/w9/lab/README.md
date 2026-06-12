# W9 Lab — GitOps, Observability, and Progressive Delivery

Bài lab này hướng dẫn xây dựng một hệ thống CI/CD hoàn chỉnh với GitOps, cấu hình giám sát, cảnh báo tự động và triển khai theo chiến lược Canary. Xuyên suốt các bài lab, bạn sẽ cấu hình hệ thống từ những bước cơ bản nhất đến lúc hệ thống có khả năng tự động hóa việc đưa ra các quyết định rollback khi có sự cố.

## Cấu trúc Repository

```text
lab/
├── README.md                    # File hướng dẫn (bạn đang đọc)
├── gitops/                      # Thư mục chứa cấu hình GitOps
│   ├── k8s/                     # Kubernetes manifests (nguồn sự thật)
│   │   ├── namespace.yaml       # Tạo namespace demo
│   │   ├── web.yaml             # Manifest cho ứng dụng web (ConfigMap, Deploy, Service)
│   │   ├── api.yaml             # Manifest cho ứng dụng api (Argo Rollouts, Service)
│   │   ├── prometheusrule.yaml  # Các rule SLO cảnh báo lỗi
│   │   ├── servicemonitor.yaml  # Thu thập metrics cho Prometheus
│   │   ├── alertmanagerconfig.yaml # Cấu hình gửi email cảnh báo
│   │   └── analysistemplate.yaml   # Cấu hình tự động phân tích cho Rollout Canary
│   ├── argocd/
│   │   ├── apps/                # Các Application con
│   │   └── root.yaml            # Root Application (Mô hình App-of-apps)
│   └── .github/
│       └── workflows/
│           └── validate.yml     # CI workflow: Validate manifest khi có Pull Request
```

## Điều kiện tiên quyết (Prerequisite)

- Docker đang chạy.
- `minikube`, `kubectl`, `git` đã cài đặt trên máy.
- Có 1 repo GitHub trống để thực hành.

---

## Lab 0 — Khởi tạo Cụm và Repository

```bash
# 1. Tạo cụm local với driver docker
minikube start -p w9 --driver=docker
kubectl config use-context w9
kubectl get nodes   # STATUS phải là Ready

# 2. Khởi tạo repository cục bộ và đưa lên Github
mkdir gitops && cd gitops
git init
git branch -M main
git remote add origin https://github.com/<ban>/gitops.git
```

_Điều kiện hoàn thành:_ Node `w9` ở trạng thái Ready.

---

## Lab 1 — Cài đặt ArgoCD vào Cụm

```bash
kubectl create ns argocd

# Cài đặt ArgoCD qua server-side apply (do kích thước CRD lớn)
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Đợi ArgoCD sẵn sàng
kubectl -n argocd rollout status deploy/argocd-server
kubectl -n argocd get pods   # Tất cả argocd-* phải Running

# Lấy mật khẩu admin mặc định
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo

# (Tùy chọn) Port-forward để truy cập ArgoCD UI
kubectl -n argocd port-forward svc/argocd-server 8080:443 &
# Truy cập: https://localhost:8080 — username: admin
```

---

## Lab 2 — Triển khai Ứng dụng đầu tiên qua GitOps

```bash
# Sửa repoURL trong file argocd/apps/web.yaml trỏ về repo GitHub của bạn.
# Apply thủ công lần duy nhất để báo cho ArgoCD biết về ứng dụng này:
kubectl apply -f gitops/argocd/apps/web.yaml

# Kiểm tra kết quả
kubectl -n argocd get app web     # Phải báo Synced / Healthy
kubectl -n demo get deploy,pod    # Các pod ứng dụng web đang Running
```

---

## Lab 3 — GitOps Loop & Self-Heal (Tự động đồng bộ và Tự chữa lành)

Kiểm tra cơ chế đồng bộ tự động và tự động phục hồi của GitOps:

```bash
# 1. Thay đổi số lượng replicas qua Git (không dùng kubectl)
# Mở gitops/k8s/web.yaml, đổi replicas thành 4. Commit và push.
# ArgoCD sẽ tự động nhận diện drift và scale lên 4 pod sau vài phút.

# 2. Kiểm tra Self-Heal bằng cách cố tình sửa tay trên cluster:
kubectl -n demo scale deploy/web --replicas=9
# Vài giây sau, ArgoCD sẽ phát hiện sự khác biệt và tự động scale về lại đúng số lượng trên Git.
```

---

## Lab 4 — Rollback ứng dụng

Trong kiến trúc GitOps, chúng ta không dùng `kubectl rollout undo` vì ArgoCD sẽ tự động ghi đè lại. Cách chuẩn xác là sử dụng git:

```bash
git revert HEAD --no-edit && git push
# ArgoCD sẽ tự đồng bộ cluster về trạng thái cấu hình của commit trước đó.
```

---

## Lab 5 — Mô hình App-of-Apps

Triển khai Root Application để quản lý tất cả các ứng dụng khác. Từ nay về sau, toàn bộ quá trình CI/CD hoàn toàn thông qua Git.

```bash
# Cập nhật repoURL trong gitops/argocd/root.yaml, commit và push.
kubectl apply -f gitops/argocd/root.yaml

# Kiểm tra
kubectl -n argocd get applications   # Phải thấy cả ứng dụng `root` và `web`
```

Từ đây, để thêm các app mới (như api, frontend, v.v.), chỉ cần thêm file cấu hình vào `argocd/apps/` trên Git. Root app sẽ tự động phát hiện và sinh ra app con mà không cần chạy bất kỳ câu lệnh `kubectl` nào nữa.

---

## Lab 6 — Đồng bộ theo thứ tự (Sync Waves)

Sử dụng Sync Waves để đảm bảo các tài nguyên được tạo theo đúng thứ tự, tránh lỗi phụ thuộc chéo (ví dụ: Deployment chạy trước khi có Namespace hoặc ConfigMap).
Thứ tự đã được cấu hình trong `web.yaml`:
`Namespace (wave -1) → ConfigMap (wave 0) → Deployment (wave 1) → Service (wave 2)`

---

## Lab 7 — CI Validate với GitHub Actions

Thêm workflow kiểm tra tính hợp lệ của Kubernetes manifests trước khi cho phép Merge code.

- File `.github/workflows/validate.yml` định nghĩa các bước CI để kiểm tra lỗi.
- Trên GitHub: Settings → Branches → Add rule cho branch `main`, yêu cầu trạng thái check `validate` phải vượt qua thành công.

---

## Lab 8 — Giám sát & Cảnh báo (Observability & Alerting)

Cấu hình hệ thống tự động giám sát và gửi thông báo khi dịch vụ gặp sự cố, đảm bảo phản ứng nhanh trước các lỗi.

1. **Thu thập metrics:** File `servicemonitor.yaml` cấu hình cho Prometheus tự động cào metrics từ `/metrics` của dịch vụ `api`. _(Lưu ý: Phải có label `release: kube-prometheus-stack`)_
2. **Cảnh báo SLO:** File `prometheusrule.yaml` phát sinh cảnh báo `ApiHighErrorRate` nếu tỉ lệ lỗi HTTP 5xx >= 5% trong 1 phút liên tục.
3. **Định tuyến gửi Email:** File `alertmanagerconfig.yaml` quy định việc gửi email cảnh báo thông qua Gmail SMTP.
    - _Về bảo mật mật khẩu:_ Cần tạo Secret lưu mật khẩu email trực tiếp trên cluster, thay vì đưa lên Git công khai:
    ```bash
    kubectl create secret generic alertmanager-smtp-password --from-literal=password="<GMAIL_APP_PASSWORD>" -n demo
    ```

---

## Lab 9 — Tự động hóa quá trình phát hành ứng dụng (Progressive Delivery & Canary)

Sử dụng Argo Rollouts để phát hành phiên bản mới. Quá trình chia traffic theo các bước, kiểm tra sức khoẻ tự động (Analysis) và tự động hủy lùi version (Auto-Abort) nếu phát hiện lỗi.

1. **Sử dụng tài nguyên Rollout:** File `api.yaml` sử dụng `Rollout` thay cho `Deployment` thông thường. Chiến lược Canary được cấu hình gồm các bước:
    - Chuyển 25% traffic -> Chạy phân tích (AnalysisRun) -> Tăng lên 50% traffic -> Tạm dừng (Pause) -> 100% traffic.
2. **Đánh giá tự động (AnalysisTemplate):** File `analysistemplate.yaml` truy vấn Prometheus lấy metric `api-success-rate`. Nếu tỉ lệ lỗi >= 5% dù chỉ xuất hiện 1 lần trong 6 lượt kiểm tra (60s), đợt Rollout lập tức bị đánh rớt (Failed).
3. **Kiểm thử Kịch bản Canary lỗi (Auto-Abort):**
    - Thay đổi cấu hình đẩy lên Git với `ERROR_RATE: "0.5"` (50% requests bị lỗi) và cập nhật phiên bản `VERSION: "v6"`.
    - Sinh traffic giả lập chạy ngầm:
        ```powershell
        1..200 | ForEach-Object { Invoke-RestMethod -Uri "http://localhost:9000" -Method Get; Start-Sleep -Milliseconds 100 }
        ```
    - Argo Rollout phát hiện lỗi qua Prometheus, tiến trình phân tích thất bại, nó sẽ tự động **Abort** bản v6 và điều hướng 100% traffic an toàn về lại bản cũ. Bạn đồng thời sẽ nhận được cảnh báo qua email.

---

## 🛠️ Phụ lục: Xử lý sự cố phần cứng máy tính giới hạn (8GB RAM)

Khi chạy toàn bộ các stack trên (ArgoCD, Prometheus, Alertmanager, App...) trên máy cá nhân có 8GB RAM, Minikube rất dễ bị quá tải tài nguyên (CPU/RAM). Điều này dẫn đến việc `prometheus` hoặc `prometheus-operator` liên tục bị `CrashLoopBackOff` (không đủ khả năng phản hồi Liveness/Readiness probe kịp thời).

**Giải pháp để duy trì cụm ổn định khi test Lab 8 và Lab 9:**
Giảm tải các ứng dụng sinh ra từ các bài Lab cũ không còn cần thiết cho việc test.

```powershell
# 1. Tắt tính năng tự chữa lành (Self-Heal) của ArgoCD đối với các app này
# (Tránh việc ArgoCD tự động kéo các pod về lại trạng thái lúc trước)
kubectl patch app backend -n argocd --type merge -p '{"spec":{"syncPolicy":null}}'
kubectl patch app frontend -n argocd --type merge -p '{"spec":{"syncPolicy":null}}'
kubectl patch app web -n argocd --type merge -p '{"spec":{"syncPolicy":null}}'

# 2. Thu gọn số lượng pod của các app phụ về 0 để giải phóng hoàn toàn RAM
kubectl scale deploy/backend deploy/frontend deploy/web --replicas=0 -n demo
```

Việc này sẽ giúp nhường không gian cho Prometheus chạy mượt mà, phân tích metrics không bị gián đoạn và quá trình tự động Abort/Promote được diễn ra trơn tru nhất có thể.
