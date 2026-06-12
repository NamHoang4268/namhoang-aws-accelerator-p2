variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}
# Không cần key_name nữa — dùng SSM để vào EC2
