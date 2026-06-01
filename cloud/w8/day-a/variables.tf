variable "bucket_name" {
  description = "Base name of the S3 bucket (a random suffix will be appended automatically)"
  type        = string
  default     = "namhoang-tf-demo"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner email address"
  type        = string
  default     = "ngokhoangnam4268@gmail.com"
}

variable "team" {
  description = "Team identifier"
  type        = string
  default     = "CD08"
}
