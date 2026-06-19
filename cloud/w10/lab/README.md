# 🛡️ AWS Homework W10 — S3 Data Protection with Amazon Macie & Alerts

Thư mục này chứa mã nguồn **Terraform** để triển khai tự động toàn bộ hạ tầng phục vụ cho bài tập: **Detect sensitive data in Amazon S3 buckets and send notifications using Amazon Macie**.

---

## 1. Thành phần tài nguyên (Resources Created)

- **S3 Bucket** (Private): Dùng để upload file chứa dữ liệu nhạy cảm PII giả lập (`files/sensitive-data.csv`).
- **Amazon Macie Account**: Kích hoạt Macie tự động.
- **Macie Classification Job** (One-time): Tạo Job quét tự động bucket S3 ngay khi apply.
- **Amazon SNS Topic & Email Subscription**: Kênh nhận email cảnh báo về địa chỉ email của bạn.
- **Amazon EventBridge Rule & Target**: Cấu hình bắt sự kiện Finding từ Macie và tự động gửi sang SNS.

---

## 2. Hướng dẫn chạy Lab

### Bước 1: Khởi tạo và Apply Terraform

1. Mở terminal tại thư mục này (`cloud/w10/lab`).
2. Khởi tạo providers:
    ```bash
    terraform init
    ```
3. Xem trước tài nguyên sẽ được tạo:
    ```bash
    terraform plan
    ```
4. Áp dụng cấu hình lên tài khoản AWS:
    ```bash
    terraform apply -auto-approve
    ```

### Bước 2: Xác nhận Đăng ký Email (Subscription Confirmation)

1. Kiểm tra hòm thư email của bạn (địa chỉ khai báo trong `terraform.tfvars` / `variables.tf` - mặc định là `ngokhoangnam4268@gmail.com`).
2. Tìm email từ AWS với tiêu đề: **"AWS Notification - Subscription Confirmation"**.
3. Click vào liên kết **Confirm Subscription** trong email.

### Bước 3: Chờ Macie chạy và chụp hình nộp bài

1. Truy cập AWS Console, vào dịch vụ **Amazon Macie** -> **Jobs**.
2. Tìm job có tên `xbrain-macie-s3-scan` và chờ trạng thái đổi sang `Complete` (mất khoảng 3-7 phút).
3. Sau khi Complete, làm theo hướng dẫn dưới đây để chụp ảnh nộp bài.

---

## 3. Báo cáo kết quả bài tập (Evidence)

_Điền mã số sinh viên của bạn tại đây:_ **XB_DN26_000** (Hoặc cập nhật đúng ID của bạn)

### Hình 1: Màn hình detect trong Macie (Findings)

_(Chụp ảnh màn hình chi tiết Findings trong dịch vụ Amazon Macie trên Console, thể hiện rõ file `sensitive-data.csv` bị phát hiện chứa thông tin nhạy cảm như Credit Cards, SSN)._

![Macie Findings](./images/macie_findings.png)

_(Bạn hãy chụp ảnh kết quả của bạn, tạo thư mục `images` và lưu với tên `macie_findings.png` tại đây)_

---

### Hình 2: Hình gửi cảnh báo về Mail

_(Chụp ảnh email cảnh báo từ `no-reply@sns.amazonaws.com` gửi về hộp thư cá nhân của bạn, chứa định dạng JSON mô tả sự kiện phát hiện dữ liệu nhạy cảm của Macie)._

![Email Alert](./images/email_alert.png)

_(Bạn hãy chụp ảnh kết quả email, lưu vào thư mục `images` với tên `email_alert.png` tại đây)_

---

## 4. Dọn dẹp tài nguyên (Clean up)

Sau khi đã chụp ảnh và nộp bài thành công, thực hiện lệnh sau để hủy toàn bộ tài nguyên đã tạo tránh phát sinh chi phí:

```bash
terraform destroy -auto-approve
```
