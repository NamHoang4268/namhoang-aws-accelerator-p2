# W8 Day A — Chuẩn bị QnA: Terraform Basics & IaC

> Scope: Terraform IaC overview + HCL syntax + S3 bucket với versioning.
> Mentor có thể hỏi ngược bất kỳ lúc nào — trả lời bằng ngôn ngữ của mình, kèm lý do.

---

## 💡 CÁCH TRẢ LỜI CHO TỐT

- Nói bằng **ngôn ngữ của mình**, không học vẹt định nghĩa
- Luôn kèm **lý do** khi nói về lựa chọn: "Em chọn X vì..."
- Kể theo flow: **Vấn đề → Giải pháp → Cách làm → Bằng chứng**
- Nếu không biết → nói thật: "Em chưa thử phần đó, nhưng em hiểu nguyên lý là..."

---

# PHẦN 1 — IaC VÀ TERRAFORM LÀ GÌ

---

### ❓ IaC là gì? Tại sao không click tay trên AWS Console?

**Trả lời đơn giản:**

> IaC (Infrastructure as Code) là cách quản lý hạ tầng bằng code thay vì click tay trên giao diện.
>
> Hãy tưởng tượng bạn cần dựng lại toàn bộ hệ thống sau khi xóa nhầm. Nếu click tay, bạn phải nhớ từng bước, dễ sai và mất hàng giờ. Nếu dùng IaC, chỉ cần chạy lại một lệnh — hệ thống dựng lại y hệt trong vài phút.
>
> Ba lợi ích chính:
> - **Reproducible:** Chạy ở đâu cũng ra kết quả giống nhau
> - **Version control:** Hạ tầng được track bằng Git như code thông thường — biết ai thay đổi gì, lúc nào
> - **Automation:** Tích hợp vào CI/CD pipeline, không cần người ngồi click

---

### ❓ Terraform khác CloudFormation thế nào? Tại sao chọn Terraform?

**Trả lời đơn giản:**

> Cả hai đều là IaC tool, nhưng khác nhau ở phạm vi:
>
> - **CloudFormation:** Chỉ dùng được với AWS, cú pháp YAML/JSON dài dòng
> - **Terraform:** Multi-cloud (AWS, GCP, Azure, Kubernetes...), cú pháp HCL ngắn gọn hơn, cộng đồng lớn hơn
>
> Trong Phase 2 dùng Terraform vì đây là tool phổ biến nhất trong thực tế DevOps, và cú pháp HCL dễ đọc hơn YAML của CloudFormation.

---

### ❓ Terraform hoạt động theo nguyên lý gì? Declarative là gì?

**Trả lời đơn giản:**

> Terraform là **declarative** — nghĩa là bạn chỉ cần khai báo "tôi muốn kết quả cuối là gì", không cần nói "làm từng bước thế nào".
>
> Ví dụ thực tế: Thay vì viết "tạo bucket → bật versioning → gắn tag", bạn chỉ cần viết "tôi muốn có một S3 bucket tên X, versioning bật, tag Y". Terraform tự tính toán cần làm gì để đạt được trạng thái đó.
>
> Nếu bucket đã tồn tại rồi, Terraform chỉ cập nhật phần khác biệt — không tạo lại từ đầu.

---

# PHẦN 2 — HCL SYNTAX CƠ BẢN

---

### ❓ Các block cơ bản trong HCL là gì?

**Trả lời đơn giản:**

> File Terraform gồm 4 loại block chính:
>
> **1. `terraform` block** — cấu hình Terraform engine:
> ```hcl
> terraform {
>   required_version = ">= 1.9.0"   # pin version tối thiểu
>   required_providers { ... }       # khai báo provider cần dùng
> }
> ```
>
> **2. `provider` block** — kết nối tới cloud provider:
> ```hcl
> provider "aws" {
>   region = "us-east-1"
> }
> ```
>
> **3. `resource` block** — tài nguyên cần tạo:
> ```hcl
> resource "aws_s3_bucket" "demo" {
>   bucket = "my-bucket"
> }
> ```
>
> **4. `variable`, `output`, `locals`** — tham số hóa và expose giá trị

---

### ❓ `variable`, `locals`, `output` khác nhau thế nào?

**Trả lời đơn giản:**

> - **`variable`** — giá trị đầu vào, có thể thay đổi khi chạy. Giống như tham số của một hàm. Dùng bằng `var.ten_bien`
> - **`locals`** — giá trị tính toán nội bộ, không thay đổi từ bên ngoài. Dùng để tránh lặp lại expression. Dùng bằng `local.ten`
> - **`output`** — giá trị expose ra sau khi apply, để xem kết quả hoặc dùng ở module khác
>
> Ví dụ trong bài:
> - `var.bucket_name` = "namhoang-tf-demo" (input)
> - `local.bucket_name` = "namhoang-tf-demo-a3f2c1b0" (tính toán từ var + random suffix)
> - `output "bucket_arn"` = ARN thực tế sau khi tạo xong

---

### ❓ Implicit dependency là gì? Terraform biết thứ tự tạo resource thế nào?

**Trả lời đơn giản:**

> Terraform tự phát hiện thứ tự tạo resource dựa trên **reference** giữa chúng.
>
> Trong bài, `aws_s3_bucket_versioning` có dòng:
> ```hcl
> bucket = aws_s3_bucket.demo.id
> ```
> Terraform thấy resource này đang dùng giá trị từ `aws_s3_bucket.demo` → tự hiểu phải tạo bucket trước, rồi mới tạo versioning sau. Không cần khai báo thứ tự thủ công.
>
> Đây gọi là **implicit dependency** — phụ thuộc ngầm qua reference.

---

# PHẦN 3 — TERRAFORM WORKFLOW

---

### ❓ 4 lệnh cơ bản của Terraform là gì? Dùng khi nào?

**Trả lời đơn giản:**

> | Lệnh | Dùng khi nào |
> |------|-------------|
> | `terraform init` | Lần đầu setup, hoặc khi thêm/đổi provider — tải provider plugins về |
> | `terraform plan` | Xem trước thay đổi sẽ xảy ra, không động vào AWS |
> | `terraform apply` | Thực sự tạo/cập nhật tài nguyên trên AWS |
> | `terraform destroy` | Xóa toàn bộ tài nguyên đã tạo |
>
> Workflow chuẩn: `init` → `plan` → review → `apply`

---

### ❓ `terraform plan` cho thấy gì? Ký hiệu `+`, `~`, `-` nghĩa là gì?

**Trả lời đơn giản:**

> `terraform plan` hiển thị diff — những gì sẽ thay đổi:
>
> - `+` (xanh lá) — resource sẽ được **tạo mới**
> - `~` (vàng) — resource sẽ được **cập nhật** (thay đổi một số thuộc tính)
> - `-` (đỏ) — resource sẽ bị **xóa**
> - `-/+` — resource sẽ bị **xóa rồi tạo lại** (replacement — thường xảy ra khi đổi tên bucket)
>
> Luôn đọc kỹ plan trước khi apply, đặc biệt chú ý dòng `-/+` vì nó xóa resource thật.

---

### ❓ State file là gì? Tại sao quan trọng?

**Trả lời đơn giản:**

> `terraform.tfstate` là file lưu trạng thái thực tế của hạ tầng — Terraform dùng nó để biết "hiện tại AWS đang có gì" và tính toán diff trong lần apply tiếp theo.
>
> Ví dụ: Nếu bạn xóa state file rồi chạy `plan`, Terraform nghĩ chưa có gì trên AWS → sẽ cố tạo lại tất cả → bị lỗi vì bucket đã tồn tại.
>
> **Trong production:** State file được lưu trên S3 (remote state) + DynamoDB để lock, tránh nhiều người apply cùng lúc gây conflict. Trong bài Day A này dùng local state (file trên máy) vì chỉ có một người làm.

---

# PHẦN 4 — NHỮNG GÌ ĐÃ LÀM TRONG BÀI

---

### ❓ Tại sao tách `aws_s3_bucket_versioning` ra resource riêng thay vì viết trong bucket?

**Trả lời đơn giản:**

> AWS provider v4+ yêu cầu cấu hình bucket phải tách thành các resource riêng biệt (versioning, encryption, lifecycle...) thay vì nhét hết vào một block `aws_s3_bucket`.
>
> Lý do AWS làm vậy: Mỗi tính năng có lifecycle riêng, tách ra giúp quản lý độc lập hơn. Ví dụ có thể bật/tắt versioning mà không cần recreate bucket.
>
> Nếu viết versioning bên trong `aws_s3_bucket` block, Terraform sẽ báo warning hoặc lỗi tùy version provider.

---

### ❓ `random_id` dùng để làm gì? Tại sao cần suffix ngẫu nhiên?

**Trả lời đơn giản:**

> S3 bucket name là **globally unique** — không ai trên toàn thế giới được dùng cùng tên. Nếu hardcode tên cố định như `namhoang-tf-demo`, rất dễ bị trùng với người khác → apply fail.
>
> `random_id` với `byte_length = 4` tạo ra 8 ký tự hex ngẫu nhiên (ví dụ: `a3f2c1b0`). Bucket name kết quả: `namhoang-tf-demo-a3f2c1b0` — gần như không thể trùng.
>
> Giá trị random này được lưu vào state file, nên mỗi lần apply sau vẫn dùng cùng suffix — bucket không bị đổi tên.

---

### ❓ `default_tags` trong provider block hoạt động thế nào?

**Trả lời đơn giản:**

> Thay vì copy-paste block `tags` vào từng resource, `default_tags` trong provider block cho phép khai báo một lần — tất cả resource AWS trong provider đó đều tự động nhận tags đó.
>
> Trong bài có 4 default tags: `Owner`, `Environment`, `Team`, `ManagedBy`.
>
> Nếu một resource cần tag riêng, vẫn thêm `tags` block vào resource đó — Terraform sẽ **merge** với default tags, không ghi đè. Đây là pattern chuẩn trong production để đảm bảo mọi resource đều có đủ tags cho cost tracking và ownership.

---

### ❓ `required_version` và `required_providers` dùng để làm gì?

**Trả lời đơn giản:**

> - **`required_version = ">= 1.9.0"`** — đảm bảo ai clone repo cũng phải dùng Terraform đủ mới. Tránh trường hợp người dùng Terraform 1.5 chạy code viết cho 1.9 bị lỗi syntax.
>
> - **`required_providers`** — pin version provider. `version = "~> 5.0"` nghĩa là dùng AWS provider từ 5.0 trở lên nhưng không vượt quá 6.0. Tránh bị breaking change khi provider tự động update lên major version mới.
>
> Đây là best practice khi làm việc nhóm hoặc CI/CD — đảm bảo mọi người dùng cùng version, kết quả nhất quán.

---

### ❓ `locals` khác `variable` thế nào? Khi nào dùng `locals`?

**Trả lời đơn giản:**

> `variable` là giá trị đầu vào từ bên ngoài (người dùng có thể override khi chạy).
> `locals` là giá trị tính toán nội bộ, không ai thay đổi được từ bên ngoài.
>
> Trong bài, `local.bucket_name = "${var.bucket_name}-${random_id.suffix.hex}"` — đây là kết quả ghép từ 2 giá trị khác. Nếu sau này cần dùng tên bucket ở nhiều chỗ (policy, logging, output...), chỉ cần dùng `local.bucket_name` thay vì lặp lại expression ghép chuỗi đó ở mọi nơi.

---

# PHẦN 5 — CÂU HỎI KHÓ BẤT NGỜ

---

### ❓ "Nếu chạy `apply` hai lần thì sao?"

> Terraform là **idempotent** — chạy nhiều lần với cùng config sẽ cho cùng kết quả. Lần đầu tạo resource, lần hai Terraform so sánh state với thực tế, thấy không có gì thay đổi → báo "No changes. Infrastructure is up-to-date."
>
> Đây là tính chất quan trọng của declarative IaC — an toàn khi chạy lại.

---

### ❓ "Tại sao không dùng `bucket_prefix` thay vì `random_id`?"

> `bucket_prefix` trong `aws_s3_bucket` cũng tạo tên ngẫu nhiên, nhưng Terraform không lưu tên đó vào state một cách tường minh — khó reference ở chỗ khác.
>
> Dùng `random_id` tường minh hơn: giá trị hex được lưu vào state, có thể dùng `random_id.suffix.hex` ở bất kỳ đâu trong config. Dễ debug và dễ đọc hơn.

---

### ❓ "Tại sao không lưu state file lên S3 ngay từ đầu?"

> Remote state (S3 + DynamoDB lock) là best practice cho team hoặc production. Nhưng để setup remote state, cần tạo S3 bucket và DynamoDB table trước — mà chính những resource đó cũng cần được tạo bằng Terraform → chicken-and-egg problem.
>
> Với bài học Day A (một người, một máy), local state đủ dùng. Remote state sẽ được áp dụng khi làm việc nhóm hoặc CI/CD pipeline.

---

### ❓ "Nếu ai đó xóa bucket trên AWS Console (không qua Terraform) thì sao?"

> Terraform sẽ phát hiện ra sự khác biệt giữa state file (nghĩ bucket đang tồn tại) và thực tế (bucket đã bị xóa) khi chạy `plan` hoặc `apply` lần sau.
>
> Kết quả: Terraform sẽ tạo lại bucket mới để đưa hạ tầng về đúng trạng thái khai báo trong code. Đây là cơ chế **drift detection** — Terraform luôn cố đưa thực tế về đúng với config.

---

# 📋 BẢNG TRA CỨU NHANH

| Thông tin | Giá trị |
|-----------|---------|
| Terraform version | >= 1.9.0 (đang dùng 1.9.8) |
| AWS provider version | ~> 5.0 |
| Random provider version | ~> 3.0 |
| Region | us-east-1 |
| Bucket base name | namhoang-tf-demo |
| Bucket name thực tế | namhoang-tf-demo-{8 ký tự hex ngẫu nhiên} |
| Versioning | Enabled |
| Tags | Owner, Environment, Team, ManagedBy (qua default_tags) |
| Owner tag | ngokhoangnam4268@gmail.com |
| Environment tag | dev |
| Team tag | CD08 |
| State file | local (terraform.tfstate) |

---

# 🎯 MẸO KHI BỊ HỎI BẤT NGỜ

| Tình huống | Cách xử lý |
|------------|------------|
| Biết rõ | Trả lời tự tin, kèm ví dụ từ code thực tế |
| Biết sơ sơ | "Em hiểu nguyên lý là... [giải thích], nhưng chưa thử sâu phần đó" |
| Không biết | "Em chưa làm phần đó, nhưng theo em hiểu thì..." |
| Bị hỏi "tại sao chọn X?" | Luôn trả lời bằng trade-off: "X vì... thay vì Y vì..." |
| Bị hỏi về state file | "State là source of truth, Terraform dùng để tính diff" |
| Bị hỏi về remote state | "Local state đủ cho cá nhân, remote state cần cho team/CI-CD" |
