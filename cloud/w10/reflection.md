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



## Day C — Platform Integration + Runbook + Cost Guard
