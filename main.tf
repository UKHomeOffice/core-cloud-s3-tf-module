resource "aws_kms_key" "s3" {
  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = local.common_tags
}

resource "aws_kms_key_policy" "bucket_kms_policy" {
  key_id = aws_kms_key.s3.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Id" : "bucket_kms_policy",
    "Statement" : [
      {
        "Sid" : "EnableIAMUserPermissions",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${var.account_id}:root"
        },
        "Action" : "kms:*",
        "Resource" : "*"
      }
    ]
  })
}


resource "aws_kms_alias" "s3" {
  name          = "alias/${var.kms_alias}"
  target_key_id = aws_kms_key.s3.id
}

resource "aws_sns_topic" "event_topic" {
  name              = "${var.project_name}-${var.bucket_name}-${var.environment}-topic"
  kms_master_key_id = "alias/aws/sns"
  tags              = local.common_tags

  policy = <<POLICY
{
    "Version":"2012-10-17",
    "Statement":[{
        "Effect": "Allow",
        "Principal": { "Service": "s3.amazonaws.com" },
        "Action": "SNS:Publish",
        "Resource": "arn:aws:sns:${var.region}:${var.account_id}:${var.project_name}-${var.bucket_name}-${var.environment}-topic",
        "Condition":{
          "StringEquals":{"aws:SourceAccount":"${var.account_id}"},
          "ArnLike":{"aws:SourceArn":"${aws_s3_bucket.this.arn}"}
        }      
    }]
}
POLICY
}

resource "aws_sns_topic_subscription" "topic-email-subscription" {
  topic_arn = aws_sns_topic.event_topic.arn
  protocol  = "email"
  endpoint  = var.email_address
}

resource "aws_s3_bucket" "this" {
  bucket = "${var.project_name}-${var.bucket_name}-${var.environment}"
  tags   = local.common_tags
}

resource "aws_s3_bucket_ownership_controls" "bucket_ownership" {
  bucket = aws_s3_bucket.this.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status     = var.enable_versioning ? "Enabled" : "Suspended"
    mfa_delete = var.mfa_delete
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.encryption_type == "aws:kms" ? aws_kms_key.s3.arn : null
      sse_algorithm     = var.encryption_type
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.this.id
  topic {
    topic_arn = aws_sns_topic.event_topic.arn
    events    = ["s3:ObjectCreated:*"]
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "cc-bucket-lifecycle-rule"
    status = "Enabled"
    filter {}
    expiration {
      days = var.lifecycle_expiration_days
    }
  }

  rule {
    id     = "cc-abort-incomplete-multipart-uploads"
    status = "Enabled"

    # No filter → applies to all multipart uploads
    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = var.days_after_initiation
    }
  }
}

resource "aws_iam_role" "cc_s3_replication_role" {
  name = "${var.project_name}-${var.bucket_name}-${var.environment}-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "s3.amazonaws.com"
        },
        "Effect" : "Allow",
        "Sid" : ""
      }
    ]
  })
}

resource "aws_iam_role_policy" "cc_s3_replication_policy" {
  count = var.enable_replication ? 1 : 0
  name  = "${var.project_name}-${var.bucket_name}-${var.environment}-policy"
  role  = aws_iam_role.cc_s3_replication_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Action" : [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket",
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
          "s3:GetObjectVersionTagging"
        ],
        "Resource" : "${aws_s3_bucket.this.arn}/*",
        "Effect" : "Allow"
      }
    ]
  })
}


resource "aws_s3_bucket_replication_configuration" "cc_bucket_replication_rule" {
  count  = var.enable_replication ? 1 : 0
  bucket = aws_s3_bucket.this.id
  role   = aws_iam_role.cc_s3_replication_role.arn
  rule {
    id = var.replication_rule

    filter {}

    destination {
      bucket        = var.destination_bucket
      storage_class = "STANDARD-IA"

      metrics {
        status = "Enabled"
      }
    }

    delete_marker_replication {
      status = "Enabled"
    }

    status = "Enabled"
  }
}

resource "aws_s3_bucket" "logs" {
  count  = var.enable_access_logs_bucket ? 1 : 0
  bucket = "${var.project_name}-${var.bucket_name}-${var.environment}-logs"
  tags   = local.common_tags
}

resource "aws_s3_bucket_logging" "bucket_logging" {
  count         = var.enable_access_logs_bucket ? 1 : 0
  bucket        = "${var.project_name}-${var.bucket_name}-${var.environment}-logs"
  target_bucket = "${var.project_name}-${var.bucket_name}-${var.environment}"
  target_prefix = "access-logs/"
}

data "aws_iam_policy_document" "cc_https_policy" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    effect = "Deny"
    actions = [
      "s3:*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
    resources = [
      "${aws_s3_bucket.this.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_policy" "cc_deny_http" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.cc_https_policy.json
}


locals {
  common_tags = merge(
    {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
    },
    var.tags
  )
}