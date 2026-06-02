# W8 Reflection

## Day A — Terraform Basics & IaC Overview

### IaC là gì và tại sao dùng Terraform?

Infrastructure as Code (IaC) là cách quản lý và provisioning hạ tầng thông qua code thay vì thao tác thủ công trên console.

Trước đây (manual): click AWS Console, dễ sai sót, không version control, khó reproduce.

Terraform giải quyết:

- **Reproducible** — cùng config chạy ở đâu cũng ra kết quả giống nhau
- **Version control** — hạ tầng được track bằng Git như code thông thường
- **Automation** — tích hợp vào CI/CD pipeline, không cần người ngồi click
- **Multi-cloud** — dùng được với AWS, GCP, Azure, Kubernetes... (khác CloudFormation chỉ dùng được AWS)

Terraform dùng ngôn ngữ HCL (HashiCorp Configuration Language) và hoạt động theo mô hình **declarative** — chỉ cần khai báo trạng thái mong muốn, Terraform tự tính toán diff và thực hiện thay đổi.

---

### Mental model quan trọng nhất — Desired State

Terraform hoạt động theo mô hình **Desired State**:

```
Bạn nói: "Tôi muốn có 1 S3 bucket tên X, versioning bật"

Terraform sẽ:
- check hiện tại (qua state + AWS API)
- nếu chưa có → tạo
- nếu khác config → sửa
- nếu dư (xóa khỏi code) → xóa
```

Đây là lý do Terraform **idempotent** — chạy nhiều lần với cùng config sẽ cho cùng kết quả.

---

### HCL Syntax cơ bản

```hcl
# terraform block — cấu hình engine, pin version
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}

# provider block — kết nối tới cloud provider
provider "aws" {
  region = "us-east-1"
}

# resource block — đơn vị hạ tầng cơ bản
# format: resource "<type>" "<local_name>"
resource "aws_s3_bucket" "demo" {
  bucket = "my-bucket"
}

# variable — tham số đầu vào, có thể override khi chạy
variable "bucket_name" {
  description = "..."
  type        = string
  default     = "namhoang-tf-demo"
}

# locals — giá trị tính toán nội bộ, không thay đổi từ bên ngoài
locals {
  bucket_name = "${var.bucket_name}-${random_id.suffix.hex}"
}

# output — expose giá trị sau khi apply
output "bucket_arn" {
  value = aws_s3_bucket.demo.arn
}
```

---

### Phân biệt 3 khái niệm hay nhầm

```
resource "aws_s3_bucket" "demo" {
  bucket = "namhoang-tf-demo-a3f2c1b0"
}
```

| Khái niệm         | Giá trị                     | Dùng ở đâu                              |
| ----------------- | --------------------------- | --------------------------------------- |
| Resource address  | `aws_s3_bucket.demo`        | Trong Terraform (reference, CLI, state) |
| Local name        | `demo`                      | Chỉ trong code Terraform                |
| Resource ID (AWS) | `namhoang-tf-demo-a3f2c1b0` | Gọi AWS API, hiển thị trên Console      |

`demo` không phải tên trên AWS — chỉ là tên nội bộ trong Terraform.

---

### State file — "bộ nhớ" của Terraform

`terraform.tfstate` lưu trạng thái thực tế của hạ tầng. Terraform dùng nó để tính diff trong lần apply tiếp theo.

State chứa:

- **Resource address** — `aws_s3_bucket.demo`
- **Resource ID** — ID thật trên AWS (dùng để map với resource thật)
- **Attributes** — toàn bộ config + computed values (ARN, domain name...)

```
ID → xác định "resource là ai"
Attributes → xác định "resource có thay đổi không"
```

Trong production: state được lưu trên S3 (remote state) + DynamoDB để lock, tránh nhiều người apply cùng lúc gây conflict. Bài Day A dùng local state vì chỉ có một người.

---

### Terraform Workflow

```
terraform init    # tải provider plugins (chạy lần đầu hoặc khi đổi provider)
terraform plan    # preview thay đổi — so sánh code vs state vs AWS thực tế
terraform apply   # apply thay đổi lên cloud
terraform destroy # xóa toàn bộ resources
```

**Đọc plan output:**

- `+` (xanh) — resource sẽ được **tạo mới**
- `~` (vàng) — resource sẽ được **cập nhật**
- `-` (đỏ) — resource sẽ bị **xóa**
- `-/+` — resource sẽ bị **xóa rồi tạo lại** (replacement — xảy ra khi đổi bucket name vì S3 không cho rename)

Luôn đọc kỹ plan trước apply, đặc biệt chú ý `-/+`.

---

### Những gì đã làm hôm nay

- Tạo S3 bucket với `aws_s3_bucket`, bật versioning bằng resource riêng `aws_s3_bucket_versioning` (đúng cách với AWS provider v4+)
- Dùng `random_id` để tạo suffix ngẫu nhiên cho bucket name — tránh trùng tên global
- Tách `variables.tf` để tham số hóa, `outputs.tf` để expose giá trị
- Dùng `locals` để tính bucket name một lần, tránh lặp lại expression
- Dùng `default_tags` trong provider block — tất cả resource AWS tự động nhận tags, không cần copy-paste vào từng resource
- Dùng `required_version` và `required_providers` để pin version, đảm bảo consistency

---

### Sai lầm phổ biến cần tránh

- ❌ Commit `.terraform/` vào Git (đây là cache, có thể regenerate)
- ❌ Không đọc `plan` trước khi `apply`
- ❌ Sửa tay trên AWS Console sau khi đã dùng Terraform (gây drift — state không khớp thực tế)
- ❌ Dùng `git add .` bừa (có thể commit state file chứa thông tin nhạy cảm)

---

### Câu hỏi còn mở

- Remote state (S3 + DynamoDB locking) setup thế nào?
- Modules giúp tái sử dụng code ra sao?
- Workspace dùng để quản lý multi-environment (dev/staging/prod) như thế nào?
- `terraform import` dùng khi nào — khi resource đã tồn tại trên AWS nhưng chưa có trong state?

---

## Day B — Kubernetes Container/Orchestration

### Tại sao cần Kubernetes?

Container giải quyết vấn đề "chạy ở đâu cũng được", nhưng khi có nhiều container thì cần orchestration:

- Container crash → tự restart thế nào?
- Scale up khi traffic tăng?
- Distribute traffic giữa nhiều container?

Kubernetes (K8s) là hệ thống orchestration tự động hóa deploy, scale, và quản lý container.

### Pod

Đơn vị nhỏ nhất trong K8s — wrapper bọc quanh một hoặc nhiều container. K8s không quản lý container trực tiếp mà quản lý Pod.

Mỗi Pod có IP riêng trong cluster, nhưng IP này thay đổi mỗi khi Pod restart → cần Service để có endpoint ổn định.

### Service

Abstraction layer tạo endpoint ổn định trỏ tới Pod. 3 loại chính:

- **ClusterIP** — chỉ accessible trong cluster (default)
- **NodePort** — expose qua port trên node (30000–32767)
- **LoadBalancer** — tạo LB ở cloud provider

Service dùng `selector` với labels để tìm đúng Pod cần route traffic tới.

### Deployment

Quản lý Pod tự động:

- Khai báo số `replicas` mong muốn
- **Self-healing**: Pod crash → tự tạo Pod mới thay thế ngay lập tức
- Hỗ trợ rolling update

Thực tế: xóa 1 Pod trong Deployment → Pod mới được tạo trong vài giây.

### Probes (Health Checks)

- **livenessProbe** — K8s kiểm tra container còn sống không. Fail → restart container
- **readinessProbe** — K8s kiểm tra container sẵn sàng nhận traffic chưa. Fail → bỏ Pod khỏi Service endpoint

Cả hai đều chạy định kỳ (`periodSeconds`), có `initialDelaySeconds` để chờ app khởi động, và `#failure=3` — phải fail 3 lần liên tiếp mới trigger action.

### ConfigMap & Secret

- **ConfigMap** — lưu config non-sensitive dưới dạng key-value, inject vào Pod qua `envFrom` hoặc `env`
- **Secret** — lưu sensitive data (password, token) dưới dạng base64. Được decode khi inject vào container — container thấy plaintext

Tách config ra khỏi image giúp thay đổi config mà không cần build lại image.

### NetworkPolicy

Kiểm soát traffic giữa các Pod. Mặc định K8s cho phép mọi Pod nói chuyện với nhau — NetworkPolicy dùng `podSelector` và `policyTypes` để restrict.

- `podSelector` — áp dụng policy cho Pod nào
- `ingress` — kiểm soát traffic đi vào
- `egress` — kiểm soát traffic đi ra

### Những gì đã làm hôm nay

| File                        | Nội dung                                   |
| --------------------------- | ------------------------------------------ |
| `01-pod.yaml`               | Pod nginx đơn giản                         |
| `02-service.yaml`           | NodePort Service expose ra ngoài cluster   |
| `03-deployment.yaml`        | Deployment 3 replicas + self-healing test  |
| `04-deployment-probes.yaml` | Deployment với liveness + readiness probes |
| `05-configmap-secret.yaml`  | ConfigMap + Secret inject vào env vars     |
| `06-networkpolicy.yaml`     | NetworkPolicy giới hạn ingress theo label  |

### Câu hỏi còn mở

- HorizontalPodAutoscaler (HPA) scale tự động dựa trên CPU/memory thế nào?
- Ingress Controller khác NodePort thế nào?
- StatefulSet dùng khi nào thay vì Deployment?
- NetworkPolicy enforcement thực tế cần CNI nào?
