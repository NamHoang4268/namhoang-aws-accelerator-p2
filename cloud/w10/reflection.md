# W10 — Secure & Operate: RBAC + Secrets + Platform Integration

> Theme: Secure & Operate — hardening cluster level, không dựa vào "developer hứa"

## Day A — RBAC + Admission Policy

### Đã làm

- Tạo 3 role: `developer` (Role trong namespace app-dev), `sre` (ClusterRole toàn cluster), `viewer` (ClusterRole read-only)
- Tạo ServiceAccount cho từng role, gán RoleBinding/ClusterRoleBinding
- Verify bằng `kubectl auth can-i`: yes/no/no/yes đúng expected
- Cài Gatekeeper v3.17.1, apply 2 ConstraintTemplate + Constraint:
    - `k8snoprivileged` — cấm container chạy privileged mode
    - `k8srequiredlabels` — bắt buộc pod phải có label `app` và `env`
- Test Gatekeeper: pod thiếu label bị Forbidden, pod đủ label được tạo

### Concepts nắm được

- RBAC kiểm soát **ai** được làm **gì** — Gatekeeper kiểm soát **làm như thế nào**
- Role vs ClusterRole: scope namespace vs toàn cluster
- ConstraintTemplate (blueprint Rego) → Constraint (instance áp dụng cho resource)
- Admission webhook: cổng gác trước etcd, Gatekeeper chạy ở đây
- `kubectl auth can-i --as=` để impersonate và test permission

### Vấn đề gặp

- Apply Constraint ngay sau ConstraintTemplate bị lỗi "CRD not found" — cần đợi ~15s để Gatekeeper register CRD
- Lệnh kubectl với `\` line continuation không hoạt động trên PowerShell — phải viết một dòng

### Câu hỏi còn mở

- Gatekeeper audit mode vs enforce mode — lab chỉ dùng enforce, chưa thử audit
- ValidatingAdmissionPolicy native K8s 1.30+ vs Gatekeeper — khác nhau thế nào trong thực tế

## Day B — Secrets Rotation + Supply Chain Security

### Đã làm

- Cài ESO qua Helm (`external-secrets/external-secrets` v2.6.0) vào namespace `external-secrets`
- Fix lỗi Gatekeeper chặn ESO pods: thêm `excludedNamespaces` vào constraint `require-app-env-labels` cho system namespaces
- Tạo secret `w10/demo/db-password` trên AWS Secrets Manager
- Tạo K8s Secret `aws-credentials` chứa AWS access key (không commit vào Git)
- Apply `SecretStore` + `ExternalSecret` — ESO tự pull secret về, tạo K8s Secret `demo-k8s-secret`
- Test rotation: update secret trên AWS → ESO sync về trong vòng 1 phút, không cần restart pod
- Build + push image `ttl.sh/namhoang-w10-demo:1h` (alpine:3.18)
- Ký image với Cosign keyless (OIDC qua Google), signature push lên registry
- Verify signature thành công: cosign claims validated + transparency log verified
- Trivy scan: 0 HIGH/CRITICAL vulnerabilities trên alpine:3.18

### Concepts nắm được

- ESO flow: SecretStore (cấu hình provider) → ExternalSecret (khai báo secret cần lấy) → K8s Secret (được tạo tự động)
- `refreshInterval` điều khiển tần suất ESO sync — rotation hoàn toàn tự động, zero-restart
- Cosign keyless: không cần tạo key — dùng OIDC token (Google/GitHub) để lấy certificate tạm từ Fulcio CA, log lên Rekor transparency log
- Verify signature xác nhận: đúng identity ký + image chưa bị tamper kể từ khi ký
- Trivy `--exit-code 1` trong CI: pipeline tự fail nếu có HIGH/CRITICAL, chặn deploy trước khi lên cluster

### Vấn đề gặp

- ESO CRD API version: `v1beta1` (cũ) → `v1` (ESO v2.6.0) — phải sửa `apiVersion` trong `secret-store.yaml` và `secret.yaml`
- Cosign trên Windows: winget cài dạng portable, exe tên `cosign-windows-amd64.exe` không tự vào PATH — cần `Set-Alias` hoặc thêm vào profile
- Gatekeeper constraint không có `excludedNamespaces` → chặn cả system tools khi restart

### Câu hỏi còn mở

- IRSA (IAM Roles for Service Accounts) vs static AWS credentials — ESO lab dùng static key, production nên dùng IRSA
- Admission webhook verify signature (Kyverno/Gatekeeper) — lab chỉ verify manual, chưa enforce ở cluster level

## Day C — Platform Integration + Runbook + Cost Guard
