// Mock providers to avoid real AWS/random calls during tests.
mock_provider "aws" {
    override_data {
        target = data.aws_iam_policy_document.cc_assume_role
        values = {
          json = "{}"
        }
    }
}

variables {
  account_id      = "100000000000"
  bucket_name     = "testbucket"
  kms_alias       = "test-kms-key"
  project_name    = "testproject"
  environment     = "test"
  encryption_type = "aws:kms"
  region          = "eu-west-2"
  source-repo     = "github.com/UKHomeOffice/core-cloud-s3-tf-module"
  email_address   = "test@test"

  tags = {
    Environment      = "test"
    Project          = "test"
    cost-centre      = "CC1000"
    account-code     = "AC1000"
    portfolio-id     = "PF1000"
    project-id       = "PR1000"
    service-id       = "SV1000"
    environment-type = "test"
    owner-business   = "test"
    budget-holder    = "testteam"
    source-repo      = "UKHomeOffice/core-cloud-s3-tf-module"
  }
}

run "validate_bucket_creation" {
  command = plan

  assert {
    condition     = aws_s3_bucket.this.bucket == "testproject-testbucket-test"
    error_message = "S3 bucket name should follow pattern: {project_name}-{bucket_name}-{environment}"
  }

  assert {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", aws_s3_bucket.this.bucket))
    error_message = "Bucket name must follow AWS naming conventions (lowercase, numbers, hyphens)"
  }
}

run "validate_kms_key_creation" {
  command = plan

  assert {
    condition     = aws_kms_key.s3.description == "KMS key for S3 bucket encryption"
    error_message = "KMS key description must be set correctly"
  }

  assert {
    condition     = aws_kms_key.s3.deletion_window_in_days == 7
    error_message = "KMS key deletion window should be 7 days"
  }

  assert {
    condition     = aws_kms_key.s3.enable_key_rotation == true
    error_message = "KMS key rotation setting should match module default"
  }
}

run "validate_kms_alias" {
  command = plan

  variables {
    kms_alias = "testalias"
  }

  # Only check what we explicitly set - the alias name should be "alias/testalias" as per the module's implementation
  assert {
    condition     = aws_kms_alias.s3.name == "alias/testalias"
    error_message = "KMS alias name should be prefixed with 'alias/' and match the provided kms_alias variable"
  }

}

run "validate_versioning_enabled" {
  command = plan

  variables {
    enable_versioning = true
  }

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "Bucket versioning must be enabled when enable_versioning is true"
  }
}

run "validate_versioning_suspended" {
  command = plan

  variables {
    enable_versioning = false
  }

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Suspended"
    error_message = "Bucket versioning must be suspended when enable_versioning is false"
  }
}

run "validate_mandatory_tags_on_bucket" {
  command = plan

  # Tags applied via local.common_tags
  assert {
    condition     = contains(keys(aws_s3_bucket.this.tags), "cost-centre")
    error_message = "cost-centre tag must be present on S3 bucket"
  }

  assert {
    condition     = contains(keys(aws_s3_bucket.this.tags), "account-code")
    error_message = "account-code tag must be present on S3 bucket"
  }

  assert {
    condition     = contains(keys(aws_s3_bucket.this.tags), "portfolio-id")
    error_message = "portfolio-id tag must be present on S3 bucket"
  }

  assert {
    condition     = contains(keys(aws_s3_bucket.this.tags), "project-id")
    error_message = "project-id tag must be present on S3 bucket"
  }

  assert {
    condition     = contains(keys(aws_s3_bucket.this.tags), "service-id")
    error_message = "service-id tag must be present on S3 bucket"
  }

  assert {
    condition     = contains(keys(aws_s3_bucket.this.tags), "environment-type")
    error_message = "environment-type tag must be present on S3 bucket"
  }

  assert {
    condition     = contains(keys(aws_s3_bucket.this.tags), "owner-business")
    error_message = "owner-business tag must be present on S3 bucket"
  }

  assert {
    condition     = contains(keys(aws_s3_bucket.this.tags), "budget-holder")
    error_message = "budget-holder tag must be present on S3 bucket"
  }
}

run "validate_public_access_block_all_enabled" {
  command = plan

  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_acls == true
    error_message = "block_public_acls must be enabled for security compliance"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_policy == true
    error_message = "block_public_policy must be enabled for security compliance"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.ignore_public_acls == true
    error_message = "ignore_public_acls must be enabled for security compliance"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.restrict_public_buckets == true
    error_message = "restrict_public_buckets must be enabled for security compliance"
  }
}

run "validate_encryption_always_enabled" {
  command = plan

  # Test that encryption is configured regardless of type
  assert {
    condition     = length(tolist(aws_s3_bucket_server_side_encryption_configuration.this.rule)) > 0
    error_message = "Server-side encryption must always be configured"
  }

  assert {
    condition     = contains(["aws:kms", "AES256"], tolist(aws_s3_bucket_server_side_encryption_configuration.this.rule)[0].apply_server_side_encryption_by_default[0].sse_algorithm)
    error_message = "Encryption algorithm must be either aws:kms or AES256"
  }
}