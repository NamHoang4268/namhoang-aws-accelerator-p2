output "bucket_id" {
  description = "The name of the S3 bucket (including random suffix)"
  value       = aws_s3_bucket.demo.id
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.demo.arn
}

output "bucket_regional_domain_name" {
  description = "The regional domain name of the S3 bucket"
  value       = aws_s3_bucket.demo.bucket_regional_domain_name
}

output "versioning_status" {
  description = "The versioning status of the S3 bucket"
  value       = aws_s3_bucket_versioning.versioning.versioning_configuration[0].status
}
