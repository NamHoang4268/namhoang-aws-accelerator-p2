#!/bin/bash
# Redirect all output to log file for debugging
exec > /var/log/user_data.log 2>&1

# Fail on error but with clear logging
set -e
trap 'echo "ERROR: Bootstrap failed at line $LINENO. Exit code: $?" >> /var/log/user_data.log; echo "BOOTSTRAP_FAILED" > /tmp/bootstrap_status' ERR

echo "Bootstrap started at $(date)"

echo "=== [1/7] Update system ==="
apt-get update -y
apt-get install -y curl wget apt-transport-https ca-certificates gnupg lsb-release

echo "=== [2/7] Install Docker ==="
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

echo "=== [3/7] Install kubectl ==="
curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

echo "=== [4/7] Install minikube ==="
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64

echo "=== [5/7] Start minikube as ubuntu user ==="
sudo -u ubuntu bash << 'MINIKUBE_SETUP'
  export HOME=/home/ubuntu
  minikube start \
    --driver=docker \
    --apiserver-ips=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4) \
    --apiserver-port=8443 \
    --embed-certs=true \
    --wait=all \
    --wait-timeout=5m
MINIKUBE_SETUP

echo "=== [6/7] Deploy hello-xbrain app ==="
sudo -u ubuntu bash << 'K8S_DEPLOY'
  export HOME=/home/ubuntu
  export KUBECONFIG=/home/ubuntu/.kube/config

  # Create namespace
  kubectl create namespace hello-xbrain || true

  # Deploy nginx with custom HTML
  kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-xbrain
  namespace: hello-xbrain
  labels:
    app: hello-xbrain
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello-xbrain
  template:
    metadata:
      labels:
        app: hello-xbrain
    spec:
      containers:
      - name: hello-xbrain
        image: nginx:1.25
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "300m"
            memory: "256Mi"
      initContainers:
      - name: init-html
        image: busybox
        command: ['sh', '-c', 'echo "<html><head><title>Hello XBrain</title><style>body{font-family:sans-serif;display:flex;justify-content:center;align-items:center;min-height:100vh;margin:0;background:#0f172a;color:#e2e8f0}.card{text-align:center;padding:2rem;background:#1e293b;border-radius:1rem;box-shadow:0 4px 20px rgba(0,0,0,.5)}h1{font-size:3rem;margin:0 0 .5rem;color:#38bdf8}p{margin:.5rem 0;color:#94a3b8}.badge{display:inline-block;margin:.25rem;padding:.25rem .75rem;background:#0284c7;border-radius:9999px;font-size:.875rem}</style></head><body><div class=\"card\"><h1>Hello, XBrain!</h1><p>Running on Kubernetes inside EC2</p><p>Deployed via Terraform 1-click</p><div><span class=\"badge\">Team CD08</span><span class=\"badge\">W8 Lab</span><span class=\"badge\">K8s + Terraform</span></div></div></body></html>" > /html/index.html']
        volumeMounts:
        - name: html
          mountPath: /html
      volumes:
      - name: html
        emptyDir: {}
EOF

  # Expose as NodePort
  kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: hello-xbrain-svc
  namespace: hello-xbrain
spec:
  type: NodePort
  selector:
    app: hello-xbrain
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
    nodePort: 30080
EOF

  # Wait for pods ready
  kubectl wait --for=condition=ready pod \
    -l app=hello-xbrain \
    -n hello-xbrain \
    --timeout=120s

K8S_DEPLOY

echo "=== [6.5/7] Setup socat port forwarding via systemd ==="
apt-get install -y socat
MINIKUBE_IP=$(sudo -u ubuntu minikube ip)

# Write systemd unit file — Restart=always ensures socat auto-recovers if it crashes
cat <<EOF > /etc/systemd/system/socat-k8s.service
[Unit]
Description=Socat Port Forwarding EC2:30080 -> Minikube NodePort:30080
After=network.target

[Service]
ExecStart=/usr/bin/socat TCP-LISTEN:30080,fork,reuseaddr TCP:${MINIKUBE_IP}:30080
Restart=always
RestartSec=5
StandardOutput=append:/var/log/socat.log
StandardError=append:/var/log/socat.log
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now socat-k8s.service
echo "socat-k8s service status: $(systemctl is-active socat-k8s.service)"

echo "=== [7/7] Create service account for Terraform K8s provider ==="
sudo -u ubuntu bash << 'SA_SETUP'
  export HOME=/home/ubuntu
  export KUBECONFIG=/home/ubuntu/.kube/config

  kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: terraform-admin
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: terraform-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: terraform-admin
  namespace: kube-system
---
apiVersion: v1
kind: Secret
metadata:
  name: terraform-admin-token
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: terraform-admin
type: kubernetes.io/service-account-token
EOF

SA_SETUP

echo "=== Bootstrap complete at $(date) ==="
echo "SUCCESS" > /tmp/bootstrap_status
touch /tmp/bootstrap_done
