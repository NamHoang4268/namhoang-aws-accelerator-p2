output "instance_id" {
  description = "EC2 Instance ID — dùng để điền vào bài 1 (alarm)"
  value       = aws_instance.cw_agent_lab.id
}

output "public_ip" {
  description = "Public IP để SSH vào EC2 verify agent status"
  value       = aws_instance.cw_agent_lab.public_ip
}
