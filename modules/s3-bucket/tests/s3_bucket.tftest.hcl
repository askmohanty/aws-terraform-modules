# Offline tests: mocked AWS provider, no credentials. The wrapped module's resource settings are
# checked by the OPA policies against a real plan in CI (see docs/ARCHITECTURE.md).
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
