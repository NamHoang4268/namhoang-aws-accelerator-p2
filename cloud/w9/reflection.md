# W9 Reflection

## Day A — GitOps & CI/CD

### Những gì đã làm

- Cài **ArgoCD** vào minikube cluster (namespace `argocd`)
- Tạo manifests K8s (Deployment, Service, Namespace) trong `day-a/argocd/`
- Tạo **ArgoCD Application** trỏ vào repo GitHub, path `cloud/w9/day-a/argocd`
- Verify GitOps loop: đổi `replicas: 2 → 3`, commit + push → ArgoCD tự sync, pod thứ 3 xuất hiện mà không cần `kubectl apply` tay
- Tạo **GitHub Actions workflow** `k8s-gitops.yml`: validate manifests khi có PR, log khi merge vào main

### Concepts nắm được

**GitOps là gì?**
Git là nguồn sự thật duy nhất cho trạng thái cluster. Thay vì `kubectl apply` tay, mọi thay đổi đi qua Git commit → ArgoCD detect → auto sync.

```
Cách cũ:   Developer → kubectl apply → Cluster
GitOps:    Developer → git push → ArgoCD → Cluster
```

**ArgoCD hoạt động thế nào?**

- Poll Git repo định kỳ (~3 phút) hoặc webhook
- So sánh desired state (Git) với live state (cluster)
- Nếu lệch → tự sync lại (nếu `syncPolicy: automated`)
- Dashboard UI hiển thị health + sync status của từng resource

**GitHub Actions trong GitOps:**

- PR → validate manifests (không apply) → comment kết quả để review
- Merge to main → trigger notify, ArgoCD tự sync sau đó
- Hai bước tách biệt: CI (kiểm tra) và CD (ArgoCD phụ trách)

### Vấn đề gặp phải

- Port 8080 bị dùng bởi process khác → dùng port 8443 cho `kubectl port-forward`
- CRD ArgoCD quá lớn → cần thêm `--server-side` flag khi apply
- kubeconfig port thay đổi sau mỗi lần restart minikube → cần sync lại từ Windows mỗi lần

### Câu hỏi còn mở

- ArgoCD sync theo webhook thay vì poll để real-time hơn thì cấu hình thế nào?
- Khi nhiều team cùng dùng 1 ArgoCD cluster, phân quyền theo namespace thế nào (RBAC)?
- `ApplicationSet` trong ArgoCD dùng khi nào so với `Application` đơn lẻ?

## Day B — Observability: SLO/SLI/OTel

### Những gì đã làm

- Cài **Prometheus + Grafana + Alertmanager** vào minikube qua Helm (`kube-prometheus-stack`)
- Cài **Loki + Promtail** vào namespace `monitoring`
- Viết **OTel Collector config** (`day-b/otel/collector-config.yaml`) — pipeline: receivers → processors → exporters
- Viết **Prometheus alert rules** (`day-b/alert-rules/slo-alert-rules.yaml`) — multi-window burn rate alert (fast 1h×5min, slow 6h×30min) cho availability và latency SLO
- Tạo **Grafana dashboard JSON** (`day-b/dashboards/slo-dashboard.json`) — SLO overview, error rate multi-window, latency percentiles, burn rate gauges
- Apply `PrometheusRule` vào cluster, verify bằng `kubectl get prometheusrule -n monitoring`

### Concepts nắm được

**Observability vs Monitoring:**

- Monitoring = WHEN (biết khi nào có vấn đề)
- Observability = WHY (hiểu tại sao có vấn đề)
- 3 Pillars: Metrics (Prometheus), Logs (Loki), Traces (Jaeger)

**OTel SDK vs Collector:**

- SDK = library trong app, tạo telemetry data
- Collector = standalone process, nhận từ nhiều app, route tới nhiều backend
- Tách app khỏi vendor → đổi backend chỉ sửa Collector config

**SLI → SLO → SLA:**

- SLI = metric thực tế đo được
- SLO = target nội bộ team đặt (99.5% availability)
- SLA = hợp đồng với khách hàng
- Error budget = 1 - SLO = 0.5% = 216 phút/tháng

**Multi-window burn rate:**

- Burn rate = tốc độ tiêu error budget
- Fast alert (critical): 1h + 5min windows, threshold 14.4× → budget cạn trong 2h
- Slow alert (warning): 6h + 30min windows, threshold 6× → budget cạn trong 5 ngày
- Multi-window giảm false positive (spike ngắn) và detect chậm cùng lúc

### Vấn đề gặp phải

- Prometheus + Grafana mất ~10 phút để pull image lần đầu (image nặng)
- `kubectl port-forward` từ Ubuntu WSL không ổn định với Windows browser → cần sync kubeconfig + copy `.minikube` certs
- `PrometheusRule` apply timeout → do kubeconfig stale, sync lại là OK
- `loki-0` restart nhiều lần (RESTARTS: 15) — bình thường trên minikube do resource constraint

### Câu hỏi còn mở

- Khi app thực sự instrument bằng OTel SDK, trace được gửi qua Collector thế nào? Correlation giữa trace ID và log?
- Prometheus retention 24h — production thì lưu bao lâu, dùng Thanos/Cortex để extend?
- Grafana alerting khác Alertmanager thế nào? Khi nào dùng cái nào?

## Day C — Progressive Delivery (Canary)

_(sẽ cập nhật sau khi hoàn thành)_
