variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
  default     = "hello-xbrain"
}

variable "environment" {
  description = "Deployment environment"
  type        = string 
  default     = "dev"
}

variable "owner" {
  description = "Owner email"
  type        = string
  default     = "ngokhoangnam4268@gmail.com"  
}

variable "team" {
  description = "Team identifier"
  type        = string
  default     = "CD08"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (need at least 2 for ALB)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "instance_type" {
  description = "EC2 instance type (t3.medium recommended for minikube)"
  type        = string
  default     = "t3.medium"
}

variable "ami_id" {
  description = "Amazon Machine Image ID (Ubuntu 22.04 LTS us-east-1)"
  type        = string
  default     = "ami-0c7217cdde317cfec"
}

variable "app_port" {
  description = "NodePort exposed by Kubernetes Service"
  type        = number
  default     = 30080
}

variable "minikube_ready_wait" {
  description = "Time in seconds to wait for EC2 to boot and SSH daemon to start before null_resource connects"
  type        = number
  default     = 90
}
