provider "aws" {
  region = "ap-southeast-1"
}

# ── SNS Topic + Email Subscription ────────────────────────
resource "aws_sns_topic" "root_login_alert" {
  name = "root-login-alert-topic"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.root_login_alert.arn
  protocol  = "email"
  endpoint  = var.email
}

resource "aws_cloudtrail" "main" {
  name                          = "root-login-trail"
  s3_bucket_name                = aws_s3_bucket.trail_bucket.id
  include_global_service_events = true  # cần để bắt Console Login event
  is_multi_region_trail         = false
  enable_log_file_validation    = true
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.trail_logs.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.trail_role.arn
}

resource "aws_s3_bucket" "trail_bucket" {
  bucket        = "root-login-trail-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_policy" "trail_policy" {
  bucket = aws_s3_bucket.trail_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:GetBucketAcl"
        Resource = "arn:aws:s3:::${aws_s3_bucket.trail_bucket.id}"
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${aws_s3_bucket.trail_bucket.id}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "trail_logs" {
  name              = "/aws/cloudtrail/root-login"
  retention_in_days = 7
}

resource "aws_iam_role" "trail_role" {
  name = "cloudtrail-cw-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "trail_policy" {
  role = aws_iam_role.trail_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.trail_logs.arn}:*"
    }]
  })
}

resource "aws_cloudwatch_log_metric_filter" "root_login" {
  name           = "RootLoginFilter"
  log_group_name = aws_cloudwatch_log_group.trail_logs.name
  pattern = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"

  metric_transformation {
    name      = "RootLoginCount"
    namespace = "Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "root_login_alarm" {
  alarm_name          = "root-account-login"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "RootLoginCount"
  namespace           = "Security"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alert when root account logs into AWS Console"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.root_login_alert.arn]
}

# ── Data source ────────────────────────────────────────────
data "aws_caller_identity" "current" {}
