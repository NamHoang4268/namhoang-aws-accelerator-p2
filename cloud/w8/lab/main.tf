terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

# ── Provider: AWS ────────────────────────────────────────────────────────────
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Owner       = var.owner
      Environment = var.environment
      Team        = var.team
      ManagedBy   = "terraform"
      Project     = var.project_name
    }
  }
}

# ── Provider: Null ───────────────────────────────────────────────────────────
# Provider #3 — used by null_resource to SSH into EC2 after boot
# and verify K8s cluster + app are running correctly.
# This solves the chicken-and-egg problem of kubernetes provider
# needing EC2 IP before the EC2 exists.
provider "null" {}

# ── TLS: Generate SSH Key Pair ───────────────────────────────────────────────
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key locally so we can SSH into EC2
resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/k8s-host.pem"
  file_permission = "0600"
}


# Register public key with AWS
resource "aws_key_pair" "k8s_host" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

# ── Security Group: EC2 ──────────────────────────────────────────────────────
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Security group for K8s host EC2"
  vpc_id      = aws_vpc.main.id

  # SSH — for provisioner and debugging
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # NodePort — ALB health check and traffic
  ingress {
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "NodePort from ALB"
  }

  # K8s API server — for Kubernetes provider
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "minikube API server"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

# ── Security Group: ALB ──────────────────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# ── EC2: K8s Host ────────────────────────────────────────────────────────────
resource "aws_instance" "k8s_host" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = aws_key_pair.k8s_host.key_name

  # Bootstrap: install Docker, minikube, kubectl, deploy app
  user_data = file("${path.module}/scripts/user_data.sh")

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.project_name}-k8s-host"
  }
}

# ── Wait for EC2 SSH to become available ─────────────────────────────────────
# Short wait (90s) for EC2 to boot and SSH daemon to start.
# The null_resource below handles waiting for the full bootstrap via polling.
resource "time_sleep" "wait_for_ssh" {
  depends_on      = [aws_instance.k8s_host]
  create_duration = "${var.minikube_ready_wait}s"
}
