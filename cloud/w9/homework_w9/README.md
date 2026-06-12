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
