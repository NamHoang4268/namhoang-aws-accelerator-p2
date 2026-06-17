# W10 Day C — AWS Cost Anomaly Detection

## Tại sao cần?

Không có Cost Anomaly Detection:
- EC2 bị exploit để mine crypto → bill tăng đột biến → phát hiện khi nhận hoá đơn
- Dev vô tình để EBS volume lớn → cost leak âm thầm hàng tuần

Cost Anomaly Detection alert ngay khi spend bất thường, không cần đợi cuối tháng.

---

## Setup trên AWS Console

### Bước 1: Tạo Cost Monitor

1. Vào **AWS Cost Management → Cost Anomaly Detection**
2. Click **Create monitor**
3. Chọn monitor type:
   - **AWS services** — monitor theo từng service (EC2, S3, RDS...)
   - **Linked account** — monitor theo account (multi-account)
   - **Cost category** — monitor theo tag/category tự định nghĩa
4. Đặt tên: `w10-demo-monitor`
5. Click **Create monitor**

### Bước 2: Tạo Alert Subscription

1. Sau khi tạo monitor → click **Create subscription**
2. Cấu hình threshold:
   - **Absolute threshold**: alert khi spend tăng > $10 (phù hợp lab)
   - **Percentage threshold**: alert khi spend tăng > 20%
3. Alert frequency: **Individual alerts** (alert ngay khi detect, không gom)
4. Thêm email nhận alert
5. Click **Create subscription**

### Bước 3: Verify

```bash
# Xem anomalies đã detect (nếu có)
aws ce get-anomalies \
  --date-interval StartDate=2026-06-01,EndDate=2026-06-17 \
  --region us-east-1

# Xem monitors đang active
aws ce get-anomaly-monitors --region us-east-1
```

---

## Best Practices

- Tạo monitor riêng cho từng service hay có cost cao: EC2, RDS, data transfer
- Threshold $10 cho lab/dev, $100+ cho production
- Alert tới Slack channel của team thay vì email cá nhân
- Review anomalies hàng tuần dù không có alert — anomaly detection không catch được mọi thứ

---

## Connect với GuardDuty

Nếu GuardDuty detect crypto mining (finding: `CryptoCurrency:EC2/BitcoinTool.B!DNS`) → Cost Anomaly Detection sẽ alert cost spike cùng lúc. 2 signals cùng nhau = high confidence incident.

Flow lý tưởng:
```
GuardDuty finding → EventBridge → Lambda isolate EC2
                                → SNS notify team
Cost Anomaly alert → Email/Slack → Team review bill
```
