# W8 Lab — K8s on AWS: Terraform 1-Click

Deploy a Kubernetes app on AWS with a **single `terraform apply`** — no manual steps.

**Author:** Ngo Kim Hoang Nam | Team CD08 | XBrain Phase 2 W8

---

## Architecture

```
Internet
    │  HTTP :80
    ▼
┌─────────────────────────────────────────────────────┐
│  Application Load Balancer (public)                  │
│  hello-xbrain-alb.us-east-1.elb.amazonaws.com       │
└──────────────────────┬──────────────────────────────┘
                       │  HTTP :30080 (NodePort)
                       ▼
┌─────────────────────────────────────────────────────┐
│  EC2 t3.medium Host (Ubuntu 22.04)                  │
│  Security Group: Inbound 30080 (from ALB), 22 (SSH)  │
│                                                     │
│  socat (Host Port 30080 ──► Minikube IP:30080)       │
│                                                     │
│  ┌──────────────────────────────────────────────┐   │
│  │  minikube (Docker driver)                    │   │
│  │  Minikube IP: 192.168.49.2                   │   │
│  │                                              │   │
│  │  Namespace: hello-xbrain                     │   │
│  │                                              │   │
│  │  Deployment: hello-xbrain (2 replicas)       │   │
│  │  Pods: nginx:1.25 + initContainer for HTML   │   │
│  │                                              │   │
│  │  Service: NodePort ──► exposed on 30080      │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘

VPC: 10.0.0.0/16 │ 2 public subnets (us-east-1a, us-east-1b)
```

> **💡 Đọc hiểu Sơ đồ Kiến trúc:**
>
> - **Tầng 1 (Internet → ALB):** Load Balancer nằm ngoài cùng, hứng traffic từ người dùng ở port 80, sau đó chỉ đường đẩy luồng traffic này xuống port 30080 của con máy ảo EC2.
> - **Tầng 2 (EC2 → `socat`):** Trạm trung chuyển. EC2 nhận traffic ở port 30080. Vì K8s node (Minikube) thực chất là một container Docker bị cô lập mạng bên trong EC2, nên ta cài một tool nhỏ tên là `socat` đóng vai trò "ống nước" hút traffic từ host EC2 đẩy thẳng vào IP của Minikube.
> - **Tầng 3 (Minikube → Pods):** Đích đến cuối. K8s Service dạng NodePort nhận traffic ở cổng 30080 và giao cho các Nginx Pods để trả về trang web hiển thị.

---

## 🚀 Execution Flow (Luồng chạy chi tiết khi gõ `terraform apply`)

1. **Khởi tạo Mạng (Networking & Security):**
    - Terraform tạo VPC, 2 Subnets (us-east-1a, us-east-1b), Internet Gateway và Route Table để mở kết nối internet.
    - Tạo 2 Security Groups: một cho ALB (mở port 80 cho public), một cho EC2 (mở port 30080 chỉ nhận traffic từ ALB, và port 22/8443 để Terraform SSH vào verify).

2. **Cấu hình Load Balancer (ALB):**
    - Tạo Application Load Balancer rải trên 2 subnet (đáp ứng điều kiện bắt buộc của AWS, dù ta chỉ chạy 1 EC2 ở subnet 1, subnet 2 để trống không tốn phí).
    - Tạo Target Group và Listener để hứng traffic từ port 80 và trỏ đích vào EC2 ở port 30080.

3. **Tạo Máy chủ & Tự động cài đặt (EC2 + Bootstrap):**
    - Tạo khóa RSA và tự động lưu file `k8s-host.pem` xuống máy local.
    - Tạo EC2 (`t3.medium`) nằm trong Subnet 1.
    - EC2 khởi động và chạy ngầm file `scripts/user_data.sh`. File này làm nhiệm vụ: Cài Docker → Cài Minikube → Tạo Pod Nginx → Tạo file HTML → Bật port forward bằng `socat`.
    - Ngay khi script cài xong K8s, nó tạo ra một file rỗng `/tmp/bootstrap_done` để làm "lá cờ" báo hiệu.

4. **Kiểm tra và Xác nhận (Verify bằng Polling):**
    - Dùng `time_sleep` bắt Terraform chờ 90 giây để hệ điều hành Ubuntu bên trong EC2 khởi động xong dịch vụ SSH.
    - Hết 90 giây, `null_resource` tự động SSH vào EC2, chạy vòng lặp 15 giây/lần để tìm "lá cờ" `/tmp/bootstrap_done` (Cơ chế Polling).
    - Thấy cờ xuất hiện → K8s đã sẵn sàng. Terraform chạy các lệnh `kubectl` kiểm tra Node/Pod và in kết quả thành công lên terminal.

5. **Kết thúc (Outputs):**
    - Terraform in ra đường link URL của ALB. Người dùng chỉ việc click vào là thấy trang web, hoàn thành quy trình 1-click thực thụ!

---

## Providers Used (≥2 requirement satisfied with 5)

| #   | Provider          | Purpose                                           |
| --- | ----------------- | ------------------------------------------------- |
| 1   | `hashicorp/aws`   | EC2, VPC, ALB, Security Groups, Key Pair          |
| 2   | `hashicorp/tls`   | Generate RSA-4096 SSH key pair                    |
| 3   | `hashicorp/null`  | SSH into EC2 post-boot, verify K8s cluster health |
| 4   | `hashicorp/local` | Write private key to local `.pem` file            |
| 5   | `hashicorp/time`  | Short wait for EC2 SSH daemon to start            |

### Why null + remote-exec instead of kubernetes provider?

The `hashicorp/kubernetes` provider requires the EC2 public IP and K8s bearer
token **at plan time** — before the EC2 exists. This is a chicken-and-egg
problem that makes true 1-click impossible.

`hashicorp/null` + `remote-exec` provisioner solves this cleanly:

- Runs **after** EC2 is created (`depends_on`)
- SSHes in using the key generated by provider #2 (`tls`)
- Polls until bootstrap script completes (`/tmp/bootstrap_done`)
- Verifies K8s nodes and app pods are healthy
- Fails loudly if anything went wrong

### Dependency chain (full apply flow)

```
tls_private_key (provider: tls)
    ↓
aws_key_pair + aws_vpc + aws_security_groups (provider: aws)
    ↓
aws_instance (user_data.sh runs: installs Docker, minikube, kubectl → deploys app)
    ├─────────────────────────────────────────────────┐
    ▼                                                 ▼
local_sensitive_file (saves key)                aws_lb + target_group + listener
    ▼                                                 │
null_resource (fix_pem_permissions)               │
    └───────────────────────┬─────────────────────────┘
                            ▼
                      time_sleep 90s (wait for SSH daemon to start)
                            ▼
                      null_resource (verify_k8s) — SSH in → poll bootstrap → verify K8s
                            ▼
                      DONE: output ALB URL
```

> **💡 Đọc hiểu cách nối (wire) Providers:**
>
> 1. Trụ cột đầu tiên là provider **`tls`**: Bắt buộc phải chạy trước tiên để đúc ra bộ khóa SSH.
> 2. Sau đó nó chia 2 ngả: Đưa Public Key cho provider **`aws`** (để khóa cửa máy ảo EC2), đồng thời đưa Private Key cho provider **`local`** (để lưu thành file `.pem` dưới laptop của bạn).
> 3. Trong lúc đó, EC2 (nhờ provider `aws`) đang tự động chạy kịch bản `user_data.sh` ngầm để cài K8s.
> 4. Cuối cùng, các luồng đều chụm lại ở chốt chặn: **`time_sleep`** (chờ 90 giây cho cửa SSH của EC2 mở) và **`null_resource`** (cầm đúng cái file `.pem` vừa tạo, SSH vào trong EC2 để xác nhận `user_data.sh` đã cài xong K8s chưa). Mọi thứ êm xuôi thì Terraform mới báo thành công!

---

## Prerequisites

- Terraform >= 1.9.0
- AWS CLI configured (`aws configure`)
- SSH client available (for null_resource remote-exec)

---

## Usage

### Deploy (1 command)

```bash
cd cloud/w8/lab

# First time: initialize providers
terraform init

# Preview what will be created (optional)
terraform plan

# Deploy everything — single command, no manual steps
terraform apply
```

Total time: ~10-12 minutes

- EC2 boot: ~1 min
- Docker + minikube install: ~5-7 min
- App deploy + pod ready: ~2 min
- ALB health check: ~2 min

### Access the app

After apply completes, Terraform prints:

```
alb_url = "http://hello-xbrain-alb-xxxxxxxxx.us-east-1.elb.amazonaws.com"
```

Open in browser → **Hello, XBrain!** page loads.

> ALB may take 1-2 extra minutes after `apply` finishes to pass health checks.
> If browser shows 502, wait 2 minutes and refresh.

### Verify K8s resources (optional)

```bash
# SSH into EC2 (command printed as output)
ssh -i ./k8s-host.pem ubuntu@<ec2_public_ip>

# Inside EC2
export KUBECONFIG=/home/ubuntu/.kube/config
kubectl get nodes
kubectl get pods -n hello-xbrain
kubectl get svc -n hello-xbrain
```

### Destroy (clean up)

```bash
terraform destroy
```

---

## Design Decisions

### Why minikube on EC2 instead of EKS?

EKS costs ~$0.10/hour for control plane alone. For a lab demo, minikube on a
single t3.medium gives a full K8s cluster at ~$0.04/hour — 60% cheaper and
fully sufficient for the challenge requirements.

### Why docker driver for minikube?

`--driver=docker` runs K8s nodes as Docker containers inside EC2. More
reliable than `--driver=none` (which requires root and modifies host network)
in a fresh Ubuntu environment.

### Why NodePort and not LoadBalancer Service?

minikube on EC2 cannot provision AWS LoadBalancers (no cloud controller).
Additionally, because the minikube docker driver runs K8s nodes inside an isolated Docker bridge network, host port `30080` is not automatically reachable from the VPC.
To bridge this gap, a host-level `socat` tunnel is used to forward host port `30080` to the minikube container's port `30080`.
This allows the AWS ALB target group to successfully route traffic to `EC2_Host:30080` and pass active health checks.

### How ALB connects to K8s app

```
Internet → ALB:80 → Target Group (EC2:30080) → socat (port forwarding) → Minikube IP:30080 → Pods:80
```

The ALB has no knowledge of Kubernetes. It treats the EC2 instance as a plain HTTP backend on port 30080. The host-level `socat` utility bridges the host port to the Minikube cluster network, and the K8s NodePort Service routes the traffic to the pods.

---

## File Structure

```
cloud/w8/lab/
├── main.tf           # Providers, EC2, Security Groups, Key Pair, time_sleep
├── network.tf        # VPC, Subnets, IGW, Route Tables
├── alb.tf            # ALB, Target Group, Listener
├── bootstrap.tf      # null_resource: SSH verify K8s cluster post-boot
├── k8s.tf            # Design decision notes (no resources here)
├── variables.tf      # Input variables
├── outputs.tf        # ALB URL, SSH command, NodePort URL
├── terraform.tfvars  # Variable values
├── scripts/
│   ├── user_data.sh      # EC2 bootstrap: Docker, minikube, kubectl, app deploy
│   └── get_k8s_token.sh  # Reference script (not used in 1-click flow)
└── README.md
```
