variable "email" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
  default     = "ngokhoangnam4268@gmail.com"
}

variable "instance_id" {
  description = "EC2 Instance ID to monitor"
  type        = string
}