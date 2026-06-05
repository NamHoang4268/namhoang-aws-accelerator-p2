aws_region   = "us-east-1"
project_name = "eatease"
environment  = "dev"
owner        = "ngokhoangnam4268@gmail.com"
team         = "CD08"

# EC2
ami_id        = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS us-east-1
instance_type = "t3.medium"

# Network
vpc_cidr              = "10.0.0.0/16"
public_subnet_cidr    = "10.0.1.0/24"
private_subnet_cidr   = "10.0.2.0/24"
private_subnet_cidr_2 = "10.0.3.0/24"
availability_zone     = "us-east-1a"
availability_zone_2   = "us-east-1b"

# RDS — password passed via env var: TF_VAR_db_password=...
db_username = "admin"
