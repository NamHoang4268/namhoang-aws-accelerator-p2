variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
  default     = "xbrain-macie"
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

variable "email_address" {
  description = "Email address to receive SNS alerts for Macie findings"
  type        = string
  default     = "ngokhoangnam4268@gmail.com"
}

variable "bucket_prefix" {
  description = "Prefix for the S3 bucket"
  type        = string
  default     = "xbrain-macie-sensitive-data"
}
