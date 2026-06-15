output "alarm_name" {
  value = aws_cloudwatch_metric_alarm.root_login_alarm.alarm_name
}

output "sns_topic_arn" {
  value = aws_sns_topic.root_login_alert.arn
}
