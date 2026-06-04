# ── Key Outputs ──────────────────────────────────────────────────────────────

output "alb_url" {
  description = "ALB DNS URL — open this in browser to access the app"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ec2_public_ip" {
  description = "EC2 public IP — use for SSH debugging"
  value       = aws_instance.k8s_host.public_ip
}

output "ec2_ssh_command" {
  description = "SSH command to access the EC2 instance"
  value       = "ssh -i ${local_sensitive_file.private_key.filename} ubuntu@${aws_instance.k8s_host.public_ip}"
}

output "app_nodeport_url" {
  description = "Direct NodePort URL (bypasses ALB)"
  value       = "http://${aws_instance.k8s_host.public_ip}:${var.app_port}"
}

output "check_bootstrap_log" {
  description = "Command to check bootstrap progress on EC2"
  value       = "ssh -i ${local_sensitive_file.private_key.filename} ubuntu@${aws_instance.k8s_host.public_ip} 'sudo tail -f /var/log/user_data.log'"
}
