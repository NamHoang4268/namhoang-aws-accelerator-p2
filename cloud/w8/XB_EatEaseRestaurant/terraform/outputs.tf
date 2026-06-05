output "web_url" {
  description = "EatEase web app URL — open in browser"
  value       = "http://${aws_instance.web.public_ip}"
}

output "ec2_public_ip" {
  description = "EC2 public IP"
  value       = aws_instance.web.public_ip
}

output "ec2_ssh_command" {
  description = "SSH command to access EC2"
  value       = "ssh -i ${local_sensitive_file.private_key.filename} ubuntu@${aws_instance.web.public_ip}"
}

output "rds_endpoint" {
  description = "RDS MySQL endpoint (private — accessible from EC2 only)"
  value       = aws_db_instance.mysql.endpoint
}

output "s3_bucket_name" {
  description = "S3 bucket for static assets"
  value       = aws_s3_bucket.static_assets.bucket
}
