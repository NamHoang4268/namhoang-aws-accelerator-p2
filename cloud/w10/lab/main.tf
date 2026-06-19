terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# ── Provider: AWS ────────────────────────────────────────────────────────────
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Owner       = var.owner
      Environment = var.environment
      Team        = var.team
      ManagedBy   = "terraform"
      Project     = var.project_name
    }
  }
}

# ── Random string for unique bucket name ─────────────────────────────────────
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# ── S3 Bucket ────────────────────────────────────────────────────────────────
resource "aws_s3_bucket" "macie_bucket" {
  bucket        = "${var.bucket_prefix}-${random_string.suffix.result}"
  force_destroy = true
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "macie_bucket_pab" {
  bucket                  = aws_s3_bucket.macie_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── S3 Object: Upload sensitive file ─────────────────────────────────────────
resource "aws_s3_object" "sensitive_data" {
  bucket       = aws_s3_bucket.macie_bucket.id
  key          = "sensitive-data.csv"
  source       = "${path.module}/files/sensitive-data.csv"
  content_type = "text/csv"

  depends_on = [aws_s3_bucket_public_access_block.macie_bucket_pab]
}

# ── Amazon Macie Classification Job ──────────────────────────────────────────
# Creates a one-time classification job to scan the S3 bucket
resource "aws_macie2_classification_job" "scan_job" {
  name     = "${var.project_name}-s3-scan"
  job_type = "ONE_TIME"

  s3_job_definition {
    bucket_definitions {
      account_id = data.aws_caller_identity.current.account_id
      buckets    = [aws_s3_bucket.macie_bucket.bucket]
    }
  }

  # Ensure object is uploaded before running job
  depends_on = [
    aws_s3_object.sensitive_data
  ]
}

# Get current AWS account details
data "aws_caller_identity" "current" {}

# ── Amazon SNS Topic ─────────────────────────────────────────────────────────
resource "aws_sns_topic" "macie_alerts" {
  name = "${var.project_name}-alerts"
}

# Allow EventBridge to publish messages to this SNS topic
resource "aws_sns_topic_policy" "allow_eventbridge" {
  arn    = aws_sns_topic.macie_alerts.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [aws_sns_topic.macie_alerts.arn]
  }
}

# ── Amazon EventBridge Rule & Target ─────────────────────────────────────────
# Triggers on any Macie Finding events
resource "aws_cloudwatch_event_rule" "macie_findings" {
  name        = "${var.project_name}-findings-rule"
  description = "Trigger SNS topic when Macie generates a finding"

  event_pattern = jsonencode({
    source      = ["aws.macie"]
    detail-type = ["Macie Finding"]
  })
}

# Connect EventBridge Rule to SNS Topic Target
resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.macie_findings.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.macie_alerts.arn
}
