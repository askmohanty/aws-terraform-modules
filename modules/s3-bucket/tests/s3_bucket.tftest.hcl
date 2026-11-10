# Offline tests: mocked AWS provider, no credentials. The wrapped module's resource settings are
# checked by the OPA policies against a real plan in CI (see docs/ARCHITECTURE.md).
mock_provider "aws" {}

variables {
  context = {
    org         = "acme"
    environment = "dev"
    region      = "eu-west-1"
  }
  name = "orders-data"
}

run "names_the_bucket_by_convention" {
  command = plan

  assert {
    condition     = output.name == "acme-dev-euw1-orders-data"
    error_message = "Bucket name must be {org}-{env}-{region_short}-{name}."
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

run "applies_standard_tags" {
  command = plan

  variables {
    tags = { Project = "orders", ManagedBy = "someone-else" }
  }

  assert {
    condition     = output.tags.ManagedBy == "terraform" && output.tags.Environment == "dev" && output.tags.Project == "orders"
    error_message = "Standard tags must be applied and win over caller tags; caller tags must be kept."
  }
}

run "allows_force_destroy_outside_prod" {
  command = plan

  variables {
    force_destroy = true
  }
}

run "refuses_force_destroy_in_prod" {
  command = plan

  variables {
    context       = { org = "acme", environment = "prod", region = "eu-west-1" }
    force_destroy = true
  }

  expect_failures = [terraform_data.guardrails]
}

run "refuses_versioning_off_in_prod" {
  command = plan

  variables {
    context            = { org = "acme", environment = "prod", region = "eu-west-1" }
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
