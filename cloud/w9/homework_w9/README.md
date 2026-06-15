# AWS Monitoring Lab (CloudWatch + SNS + Agent)

## Mô tả

Lab này gồm 2 phần:

### 1. Alarm

- Tạo SNS Topic + Subscription (Email)
- Tạo CloudWatch Alarm cho EC2 CPU > 80%
- Gửi email khi alarm trigger

### 2. CloudWatch Agent

- Tạo IAM Role cho EC2
- Cài CloudWatch Agent
- Đẩy metrics custom (memory, disk)

---

## Kiến trúc

EC2 → CloudWatch → SNS → Email

---

## 📸 Kết quả

- Alarm hoạt động ✔
- Nhận email ✔
- Metrics CWAgent hiển thị ✔

---

## 🚀 Công nghệ sử dụng

- AWS CloudWatch
- SNS
- EC2
- IAM

---

## 📂 Chi tiết

- [Alarm](./alarm)
- [Agent](./agent)

---

## Alert on AWS Root Account Login

### Mô tả

Thiết lập cảnh báo tự động khi có đăng nhập vào AWS bằng tài khoản Root. Đây là best practice bảo mật quan trọng — root account không bao giờ nên được dùng trong daily operations.

### Kiến trúc

```
Root Login Event
    → CloudTrail (bắt ConsoleLogin event toàn cầu)
    → CloudWatch Logs (/aws/cloudtrail/root-login)
    → Metric Filter (pattern: userIdentity.type = "Root")
    → Custom Metric: Security/RootLoginCount
    → CloudWatch Alarm (threshold >= 1)
    → SNS Topic → Email Alert
```

### Cách chạy

```bash
cd cloud/w9/homework_w9/root-login-alert
terraform init
terraform plan
terraform apply
```

Sau khi apply, vào Gmail xác nhận SNS subscription rồi login bằng root account để trigger alarm.

### Chi tiết

- [root-login-alert](./root-login-alert)
- [Evidence](./root-login-alert/root_alert_evidence.md)
