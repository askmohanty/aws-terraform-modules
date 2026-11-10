module "naming" {
  source = "../naming"

  org                  = var.context.org
  environment          = var.context.environment
  allowed_environments = var.context.allowed_environments
  region               = var.context.region
  name                 = var.name
  owner                = var.context.owner
  cost_centre          = var.context.cost_centre
  extra_tags           = merge(var.context.extra_tags, var.tags)
}

locals {
  bucket_name = var.name_suffix == null ? module.naming.id : "${module.naming.id}-${var.name_suffix}"
  is_prod     = var.context.environment == "prod"

  lifecycle_rules = concat(
    [{
      id                                     = "abort-incomplete-multipart-uploads"
      enabled                                = true
      filter                                 = { prefix = "" }
      abort_incomplete_multipart_upload_days = 7
    }],
    var.versioning_enabled && var.noncurrent_version_expiration_days != null ? [{
      id                            = "expire-noncurrent-versions"
      enabled                       = true
      filter                        = { prefix = "" }
      noncurrent_version_expiration = { days = var.noncurrent_version_expiration_days }
    }] : [],
    [for r in var.lifecycle_rules : {
      id         = r.id
      enabled    = true
      filter     = { prefix = r.prefix }
      expiration = r.expiration_days == null ? null : { days = r.expiration_days }
      transition = [for t in r.transitions : { days = t.days, storage_class = t.storage_class }]
    }],
  )
}

# Guardrails that depend on more than one input. A failed precondition stops the plan.
resource "terraform_data" "guardrails" {
  lifecycle {
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

module "bucket" {
  # terraform-aws-modules/s3-bucket v5.17.0, pinned to a commit
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=9afa4fc8c8f1e0b3fd913474c1bef8d0c454b235"

  bucket        = local.bucket_name
  force_destroy = var.force_destroy
  tags          = module.naming.tags

  # No ACLs: the bucket owner owns every object; access is by policy only.
  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"

  # No public access, ever.
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  versioning = { enabled = tostring(var.versioning_enabled) }

  # KMS encryption is always on.
  server_side_encryption_configuration = {
    rule = {
      bucket_key_enabled = true
      apply_server_side_encryption_by_default = {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = var.kms_key_arn
      }
    }
  }

  # Policy: deny non-TLS and TLS < 1.2; with a customer key, deny uploads that name another key.
  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true
  attach_deny_incorrect_kms_key_sse     = var.kms_key_arn != null
  allowed_kms_key_arn                   = var.kms_key_arn
  attach_policy                         = var.policy_json != null
  policy                                = var.policy_json

  lifecycle_rule = local.lifecycle_rules

  logging = var.access_logging == null ? null : {
    target_bucket = var.access_logging.target_bucket
    target_prefix = var.access_logging.target_prefix
  }

  depends_on = [terraform_data.guardrails]
}
