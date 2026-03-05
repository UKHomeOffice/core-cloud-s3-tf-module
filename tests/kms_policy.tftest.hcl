# KMS Key policy test

# Import shared provider configuration for local testing
# This allows tests to run without real AWS credentials

provider "aws" {
  region                      = "eu-west-2"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret_key"
}

variables {
  bucket_name  = "testbucket"
  project_name = "testproject"
  environment  = "test"
  region       = "eu-west-2"
  source-repo  = "github.com/UKHomeOffice/core-cloud-tooling-resources-terragrunt"
  account_id   = "100000000000"

  tags = {
    Environment  = "test-ops-tooling"
    Project      = "cc"
    cost-centre  = "1709144"
    account-code = "521835"
    portfolio-id = "CTO"
    project-id   = "CC"
    service-id   = "QE"
  }
}

run "kms_policy_test" {
  command = plan

  assert {
    condition     = jsondecode(aws_kms_key_policy.kms_policy.policy)["Statement"][0]["Sid"] == "Enable IAM User Permissions"
    error_message = "KMS policy must contain the Enable IAM User Permissions statement."
  }
  assert {
    condition     = jsondecode(aws_kms_key_policy.kms_policy.policy)["Statement"][0]["Action"] == "kms:*"
    error_message = "KMS policy must allow kms:* actions."
  }
}
