variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
  default     = ""
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = ""
}

variable "kms_alias" {
  description = "KMS key alias for bucket encryption"
  type        = string
  nullable    = false
}

variable "enable_versioning" {
  description = "Enable versioning for the bucket"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to be applied to the bucket"
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      contains(keys(var.tags), "cost-centre"),
      contains(keys(var.tags), "account-code"),
      contains(keys(var.tags), "portfolio-id"),
      contains(keys(var.tags), "project-id"),
      contains(keys(var.tags), "portfolio-id"),
      contains(keys(var.tags), "service-id"),
      contains(keys(var.tags), "environment-type"),
      contains(keys(var.tags), "owner-business"),
      contains(keys(var.tags), "budget-holder")
    ])
    error_message = "Tags must include all mandatory fields."
  }

}

variable "encryption_type" {
  description = "The server-side encryption algorithm to use. Valid values are 'aws:kms' or 'AES256'. AES256 is for SSE-S3"
  type        = string
  default     = "aws:kms"

  validation {
    condition     = contains(["aws:kms", "AES256"], var.encryption_type)
    error_message = "The encryption_type must be either 'aws:kms' or 'AES256'."
  }
}

variable "source-repo" {
  description = "The GitHub repository that made the AWS S3"
  type        = string
}

variable "lifecycle_expiration_days" {
  description = "Number of days to keep s3 objects before expiration"
  type        = number
  default     = 30
}

variable "days_after_initiation" {
  description = "Specifies the number of days after initiating a multipart upload when the multipart upload must be completed."
  default     = 15
  type        = number
}

variable "replication_rule" {
  type        = string
  description = "The name of the replication rule applied to S3"

  validation {
    condition     = length(var.replication_rule) >= 1 && length(var.replication_rule) <= 256
    error_message = "The replication_rule name must be less than 256 characters."
  }
}

variable "destination_bucket" {
  type        = string
  description = "The ARN of the existing s3 bucket to replicate generated reports to."

  validation {
    condition     = length(var.destination_bucket) >= 1 && length(var.destination_bucket) <= 256
    error_message = "The destination_bucket ARN must be less than 256 characters."
  }
}

variable "iam_role" {
  type        = string
  description = "Name of the role. If omitted, Terraform will assign a random, unique name"
}

variable "iam_role_policy_name" {
  type        = string
  description = "Name of the IAM Role Policy."
}

variable "logging_bucket_name" {
  type        = string
  description = "Name of the S3 bucket for logs."
}

variable "env" {
  type        = string
  description = "Name of the environment."
}

variable "enable_access_logs_bucket" {
  type        = bool
  default     = true
  description = "Whether s3 server access logging should be enabled."
}

variable "s3_access_logs_bucket_name" {
  type        = string
  default     = "s3-access-logs"
  description = "Name of the s3 bucket to store access logs."
}