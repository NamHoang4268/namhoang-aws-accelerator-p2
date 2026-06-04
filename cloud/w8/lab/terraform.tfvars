aws_region   = "us-east-1"
project_name = "hello-xbrain"
environment  = "dev"
owner        = "ngokhoangnam4268@gmail.com"
team         = "CD08"

# EC2 config
instance_type = "t3.medium"
ami_id        = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS us-east-1

# Network
vpc_cidr            = "10.0.0.0/16"
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
availability_zones  = ["us-east-1a", "us-east-1b"]

# App
app_port = 30080

# Wait 90s for EC2 SSH daemon to start.
# The null_resource in bootstrap.tf handles the actual bootstrap polling.
minikube_ready_wait = 90
