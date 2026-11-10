# Stack-wide facts come from the provider: its region and its default_tags (Org, Environment, ...).
data "aws_region" "current" {}

data "aws_default_tags" "current" {}

locals {
  stack_tags = data.aws_default_tags.current.tags
  # When Org or Environment is missing, terraform_data.guardrails stops the plan with an exact fix.
  # The placeholders only keep the naming module from failing first with a less helpful message.
  stack_ok = contains(keys(local.stack_tags), "Org") && contains(keys(local.stack_tags), "Environment")
}

module "naming" {
  source = "../../internal/naming"

  org         = local.stack_ok ? local.stack_tags["Org"] : "unset"
  environment = local.stack_ok ? local.stack_tags["Environment"] : "dev"
  region      = data.aws_region.current.region
  name        = var.name
}

locals {
  bucket_name = var.name_suffix == null ? module.naming.id : "${module.naming.id}-${var.name_suffix}"
  is_prod     = lookup(local.stack_tags, "Environment", "") == "prod"

  # Org, Environment, Owner, ... are applied by the provider's default_tags; never override them here.
  resource_tags = merge(
    { for k, v in var.tags : k => v if !contains(keys(local.stack_tags), k) },
    { Name = local.bucket_name, Region = data.aws_region.current.region, ManagedBy = "terraform" },
  )
}

# Guardrails that depend on more than one input. A failed precondition stops the plan.
resource "terraform_data" "guardrails" {
  lifecycle {
    precondition {
      condition     = local.stack_ok
      error_message = "Set the stack's Org and Environment once on the AWS provider: provider \"aws\" { default_tags { tags = { Org = \"acme\", Environment = \"dev\" } } }."
    }
    precondition {
      condition     = length(local.bucket_name) <= 63
      error_message = "Bucket name \"${local.bucket_name}\" is longer than 63 characters. Shorten `name` or `name_suffix`."
    }
    precondition {
      condition     = !(local.is_prod && var.force_destroy)
      error_message = "`force_destroy` is refused in prod: it lets `terraform destroy` delete a bucket that still holds data."
    }
    precondition {
      condition     = !(local.is_prod && !var.versioning_enabled)
      error_message = "Versioning cannot be turned off in prod."
    }
  }
}

resource "aws_s3_bucket" "this" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy
  tags          = local.resource_tags

  depends_on = [terraform_data.guardrails]
}

# No ACLs: the bucket owner owns every object and access is controlled by policy only.
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# No public access, ever.
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
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# KMS encryption is always on: the aws/s3 key, or the customer key in kms_key_arn.
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  # Whole-bucket rules use an empty filter.
  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"
    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  dynamic "rule" {
    for_each = var.versioning_enabled && var.noncurrent_version_expiration_days != null ? [var.noncurrent_version_expiration_days] : []
    content {
      id     = "expire-noncurrent-versions"
      status = "Enabled"
      filter {}

      noncurrent_version_expiration {
        noncurrent_days = rule.value
      }
    }
  }

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = "Enabled"

      # Empty filter for the whole bucket, a prefix filter otherwise.
      dynamic "filter" {
        for_each = rule.value.prefix == "" ? [true] : []
        content {}
      }
      dynamic "filter" {
        for_each = rule.value.prefix == "" ? [] : [rule.value.prefix]
        content {
          prefix = filter.value
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expiration_days == null ? [] : [rule.value.expiration_days]
        content {
          days = expiration.value
        }
      }

      dynamic "transition" {
        for_each = rule.value.transitions
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }
    }
  }

  # Rules on object versions need versioning configured first.
  depends_on = [aws_s3_bucket_versioning.this]
}

resource "aws_s3_bucket_logging" "this" {
  count = var.access_logging == null ? 0 : 1

  bucket        = aws_s3_bucket.this.id
  target_bucket = var.access_logging.target_bucket
  target_prefix = var.access_logging.target_prefix
}

locals {
  bucket_resources = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"]

  required_statements = concat(
    [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = local.bucket_resources
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
      {
        Sid       = "DenyOutdatedTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = local.bucket_resources
        Condition = { NumericLessThan = { "s3:TlsVersion" = "1.2" } }
      },
    ],
    # With a customer key, uploads that name a different key are denied.
    var.kms_key_arn == null ? [] : [{
      Sid       = "DenyOtherKmsKeys"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.this.arn}/*"
      Condition = { StringNotEqualsIfExists = { "s3:x-amz-server-side-encryption-aws-kms-key-id" = var.kms_key_arn } }
    }],
  )

  # The caller's statements (a single object or a list) come after the required ones.
  caller_statements = var.policy_json == null ? [] : flatten([jsondecode(var.policy_json).Statement])
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = concat(local.required_statements, local.caller_statements)
  })

  # The public access block must exist first, or AWS rejects the policy with a conflicting operation.
  depends_on = [aws_s3_bucket_public_access_block.this]
}
