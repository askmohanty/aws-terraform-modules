# Offline tests: mocked AWS provider, no credentials. Security settings are asserted on the resources
# below; CI also plans the examples against an AWS emulator and runs the OPA policies on the plan.
mock_provider "aws" {
  # A provider configured with region eu-west-1 and the stack's default tags.
  override_data {
    target = data.aws_region.current
    values = { region = "eu-west-1" }
  }
  override_data {
    target = data.aws_default_tags.current
    values = { tags = { Org = "acme", Environment = "dev", Owner = "orders-team" } }
  }
}

variables {
  name = "orders-data"
}

run "names_the_bucket_from_provider_tags_and_region" {
  command = plan

  assert {
    condition     = output.name == "acme-dev-euw1-orders-data"
    error_message = "Bucket name must be {Org}-{Environment}-{region_short}-{name}."
  }
}

run "follows_the_provider_region" {
  command = plan

  override_data {
    target = data.aws_region.current
    values = { region = "ap-southeast-2" }
  }

  assert {
    condition     = output.name == "acme-dev-apse2-orders-data"
    error_message = "The region in the name must come from the provider."
  }
}

run "appends_name_suffix" {
  command = plan

  variables {
    name_suffix = "a1b2"
  }

  assert {
    condition     = output.name == "acme-dev-euw1-orders-data-a1b2"
    error_message = "name_suffix must be appended."
  }
}

run "sets_name_region_managedby_and_keeps_caller_tags" {
  command = plan

  variables {
    tags = { DataClass = "confidential" }
  }

  assert {
    condition = (
      output.tags.Name == "acme-dev-euw1-orders-data" &&
      output.tags.Region == "eu-west-1" &&
      output.tags.ManagedBy == "terraform" &&
      output.tags.DataClass == "confidential"
    )
    error_message = "The module must set Name, Region and ManagedBy and keep caller tags."
  }
}

run "callers_cannot_override_stack_tags" {
  command = plan

  variables {
    tags = { Environment = "prod", Owner = "someone-else", ManagedBy = "hand" }
  }

  assert {
    condition = (
      !contains(keys(output.tags), "Environment") &&
      !contains(keys(output.tags), "Owner") &&
      output.tags.ManagedBy == "terraform"
    )
    error_message = "Stack tags come only from the provider's default_tags; ManagedBy is always terraform."
  }
}

run "refuses_provider_without_org_and_environment" {
  command = plan

  override_data {
    target = data.aws_default_tags.current
    values = { tags = { Owner = "orders-team" } }
  }

  expect_failures = [terraform_data.guardrails]
}

run "allows_force_destroy_outside_prod" {
  command = plan

  variables {
    force_destroy = true
  }
}

run "refuses_force_destroy_in_prod" {
  command = plan

  override_data {
    target = data.aws_default_tags.current
    values = { tags = { Org = "acme", Environment = "prod" } }
  }

  variables {
    force_destroy = true
  }

  expect_failures = [terraform_data.guardrails]
}

run "refuses_versioning_off_in_prod" {
  command = plan

  override_data {
    target = data.aws_default_tags.current
    values = { tags = { Org = "acme", Environment = "prod" } }
  }

  variables {
    versioning_enabled = false
  }

  expect_failures = [terraform_data.guardrails]
}

run "refuses_names_longer_than_63" {
  command = plan

  variables {
    name        = "a-very-long-bucket-purpose-name-abcdefg"
    name_suffix = "abcdefghijkl"
  }

  expect_failures = [terraform_data.guardrails]
}

run "accepts_policy_scoped_to_a_role" {
  command = plan

  variables {
    policy_json = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid       = "ReadForReporting"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::111122223333:role/reporting" }
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::acme-dev-euw1-orders-data/*"
      }]
    })
  }
}

run "refuses_policy_open_to_everyone" {
  command = plan

  variables {
    policy_json = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid       = "Public"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::acme-dev-euw1-orders-data/*"
      }]
    })
  }

  expect_failures = [var.policy_json]
}

run "refuses_wildcard_inside_aws_principal_list" {
  command = plan

  variables {
    policy_json = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid       = "Sneaky"
        Effect    = "Allow"
        Principal = { AWS = ["arn:aws:iam::111122223333:root", "*"] }
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::acme-dev-euw1-orders-data/*"
      }]
    })
  }

  expect_failures = [var.policy_json]
}

run "refuses_malformed_kms_key_arn" {
  command = plan

  variables {
    kms_key_arn = "alias/my-key"
  }

  expect_failures = [var.kms_key_arn]
}

run "refuses_unknown_storage_class" {
  command = plan

  variables {
    lifecycle_rules = [{
      id          = "archive"
      transitions = [{ days = 30, storage_class = "COLD" }]
    }]
  }

  expect_failures = [var.lifecycle_rules]
}

run "refuses_bad_name_suffix" {
  command = plan

  variables {
    name_suffix = "Not_Valid"
  }

  expect_failures = [var.name_suffix]
}

# ---- Security settings on the resources themselves (mocked apply creates nothing real)

run "secure_settings_by_default" {
  command = apply

  assert {
    condition = (
      aws_s3_bucket_public_access_block.this.block_public_acls &&
      aws_s3_bucket_public_access_block.this.block_public_policy &&
      aws_s3_bucket_public_access_block.this.ignore_public_acls &&
      aws_s3_bucket_public_access_block.this.restrict_public_buckets
    )
    error_message = "All four public access block settings must be on."
  }

  assert {
    condition     = one(aws_s3_bucket_ownership_controls.this.rule).object_ownership == "BucketOwnerEnforced"
    error_message = "ACLs must be disabled (BucketOwnerEnforced)."
  }

  assert {
    condition = (
      one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms" &&
      one(aws_s3_bucket_server_side_encryption_configuration.this.rule).bucket_key_enabled
    )
    error_message = "Default encryption must be KMS with bucket keys."
  }

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "Versioning must be on by default."
  }

  assert {
    condition = alltrue([
      for sid in ["DenyInsecureTransport", "DenyOutdatedTLS"] :
      contains([for s in jsondecode(aws_s3_bucket_policy.this.policy).Statement : s.Sid], sid)
    ])
    error_message = "The bucket policy must deny non-TLS requests and TLS older than 1.2."
  }

  assert {
    condition = (
      contains([for r in aws_s3_bucket_lifecycle_configuration.this.rule : r.id], "abort-incomplete-multipart-uploads") &&
      contains([for r in aws_s3_bucket_lifecycle_configuration.this.rule : r.id], "expire-noncurrent-versions")
    )
    error_message = "Default lifecycle rules must be present."
  }

  assert {
    condition     = !aws_s3_bucket.this.force_destroy && length(aws_s3_bucket_logging.this) == 0
    error_message = "force_destroy off and no logging target by default."
  }
}

run "customer_key_encrypts_and_denies_other_keys" {
  command = apply

  variables {
    kms_key_arn = "arn:aws:kms:eu-west-1:111122223333:key/1234abcd-12ab-34cd-56ef-1234567890ab"
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default[0].kms_master_key_id == var.kms_key_arn
    error_message = "The customer key must be the default encryption key."
  }

  assert {
    condition     = contains([for s in jsondecode(aws_s3_bucket_policy.this.policy).Statement : s.Sid], "DenyOtherKmsKeys")
    error_message = "Uploads naming another key must be denied."
  }
}

run "caller_statements_follow_the_required_ones" {
  command = apply

  variables {
    policy_json = jsonencode({
      Version = "2012-10-17"
      Statement = {
        Sid       = "ReadForReporting"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::111122223333:role/reporting" }
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::acme-dev-euw1-orders-data/*"
      }
    })
  }

  assert {
    condition     = [for s in jsondecode(aws_s3_bucket_policy.this.policy).Statement : s.Sid] == ["DenyInsecureTransport", "DenyOutdatedTLS", "ReadForReporting"]
    error_message = "Required deny statements come first, then the caller's (a single statement object is accepted)."
  }
}

run "versioning_off_outside_prod" {
  command = apply

  variables {
    versioning_enabled = false
  }

  assert {
    condition = (
      aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Suspended" &&
      !contains([for r in aws_s3_bucket_lifecycle_configuration.this.rule : r.id], "expire-noncurrent-versions")
    )
    error_message = "Versioning off suspends it and drops the noncurrent-version rule."
  }
}

run "lifecycle_filters_whole_bucket_and_prefix" {
  command = apply

  variables {
    lifecycle_rules = [
      { id = "all", expiration_days = 365 },
      { id = "exports", prefix = "exports/", transitions = [{ days = 30, storage_class = "STANDARD_IA" }] },
    ]
  }

  assert {
    # An empty filter's prefix is null in Terraform and a mock placeholder in OpenTofu, so assert
    # only that the whole-bucket rule does not filter on the prefix and the prefix rule does.
    condition = (
      length(one([for r in aws_s3_bucket_lifecycle_configuration.this.rule : r if r.id == "all"]).filter) == 1 &&
      one([for r in aws_s3_bucket_lifecycle_configuration.this.rule : r if r.id == "all"]).filter[0].prefix != "exports/" &&
      one([for r in aws_s3_bucket_lifecycle_configuration.this.rule : r if r.id == "exports"]).filter[0].prefix == "exports/"
    )
    error_message = "A rule without a prefix gets an empty filter; a prefix rule filters on its prefix."
  }
}

run "access_logging_when_requested" {
  command = apply

  variables {
    access_logging = { target_bucket = "acme-dev-euw1-logs", target_prefix = "s3/" }
  }

  assert {
    condition     = length(aws_s3_bucket_logging.this) == 1 && aws_s3_bucket_logging.this[0].target_prefix == "s3/"
    error_message = "Access logging must be configured when requested."
  }
}
