output "s3_bucket_name" {
  description = "The name of the S3 bucket created for scanning"
  value       = aws_s3_bucket.macie_bucket.id
}

output "sns_topic_arn" {
  description = "The ARN of the SNS topic for notifications"
  value       = aws_sns_topic.macie_alerts.arn
}

output "macie_job_name" {
  description = "The name of the Macie classification job"
  value       = aws_macie2_classification_job.scan_job.name
}

output "macie_job_id" {
  description = "The ID of the Macie classification job"
  value       = aws_macie2_classification_job.scan_job.id
}

output "eventbridge_rule_name" {
  description = "The name of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.macie_findings.name
}
