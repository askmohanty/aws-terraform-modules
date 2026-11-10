# AWS S3 bucket Terraform module

A private, encrypted, versioned S3 bucket that refuses public access and insecure transport.

Creates the bucket with ownership controls (ACLs disabled), a public access block, versioning, KMS default encryption, lifecycle rules, optional server access logging and a bucket policy.

## Security built in

These are always on; no input turns them off:

- **No public access.** All four public access block settings are on and ACLs are disabled (`BucketOwnerEnforced`). A `policy_json` that grants access to everyone (`Principal: "*"`, also inside an `AWS` list) is refused at plan time.
- **Encrypted at rest.** Default encryption is SSE-KMS with S3 Bucket Keys, using the `aws/s3` key or your `kms_key_arn`. With a customer key, uploads that request a different key are denied by the bucket policy.
- **Encrypted in transit.** The bucket policy denies requests without TLS and requests using TLS older than 1.2.
- **Recoverable.** Versioning is on by default; previous versions expire after 90 days (configurable) and unfinished multipart uploads are removed after 7 days.
- **Stricter in prod.** With `Environment = "prod"`, `force_destroy = true` and `versioning_enabled = false` are refused.
- **Named and tagged by convention.** The name is `{Org}-{Environment}-{region}-{name}` from the provider's `default_tags` and region; the module adds `Name`, `Region` and `ManagedBy` tags.

## Usage

Every example assumes the stack's facts are set once on the provider:

```hcl
provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      Org         = "acme"
      Environment = "prod"
      Owner       = "orders-team"
    }
  }
}
```

### Private bucket with the secure defaults

```hcl
module "orders_data" {
  source  = "askmohanty/hardened-modules/aws//modules/s3-bucket"
  version = "0.3.0" # x-release-please-version

  name        = "orders-data" # -> acme-prod-euw1-orders-data-a1b2
  name_suffix = "a1b2"        # bucket names are global; a suffix avoids collisions
}
```

### Bucket encrypted with a customer-managed KMS key

```hcl
module "orders_data" {
  source  = "askmohanty/hardened-modules/aws//modules/s3-bucket"
  version = "0.3.0" # x-release-please-version

  name        = "orders-data"
  name_suffix = "a1b2"
  kms_key_arn = "arn:aws:kms:eu-west-1:111122223333:key/1234abcd-12ab-34cd-56ef-1234567890ab"
}
```

### Bucket with access logging and lifecycle rules

```hcl
module "exports" {
  source  = "askmohanty/hardened-modules/aws//modules/s3-bucket"
  version = "0.3.0" # x-release-please-version

  name        = "exports"
  name_suffix = "a1b2"

  access_logging = {
    target_bucket = "acme-prod-euw1-access-logs-a1b2"
    target_prefix = "exports/"
  }

  lifecycle_rules = [
    { id = "expire-tmp", prefix = "tmp/", expiration_days = 7 },
    { id = "archive", prefix = "reports/", transitions = [{ days = 30, storage_class = "STANDARD_IA" }, { days = 180, storage_class = "GLACIER_IR" }] },
  ]
}
```

### Bucket with a custom policy

Your statements are added after the built-in deny statements. Grant access to specific principals only.

```hcl
module "reports" {
  source  = "askmohanty/hardened-modules/aws//modules/s3-bucket"
  version = "0.3.0" # x-release-please-version

  name        = "reports"
  name_suffix = "a1b2"

  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "ReadForReporting"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::111122223333:role/reporting" }
      Action    = "s3:GetObject"
      Resource  = "arn:aws:s3:::acme-prod-euw1-reports-a1b2/*"
    }]
  })
}
```

### Many buckets from a map

```hcl
variable "buckets" {
  type = map(object({
    versioning_enabled = optional(bool, true)
    lifecycle_rules    = optional(list(any), [])
  }))
}

module "bucket" {
  source   = "askmohanty/hardened-modules/aws//modules/s3-bucket"
  version  = "0.3.0" # x-release-please-version
  for_each = var.buckets

  name               = each.key # orders-data -> acme-prod-euw1-orders-data
  versioning_enabled = each.value.versioning_enabled
  lifecycle_rules    = each.value.lifecycle_rules
}
```

## Notes

- **Set `Org` and `Environment` on the provider.** The module reads them from `default_tags` and stops the plan with the exact fix if either is missing. Do not repeat them in `tags`; stack-level keys in `tags` are ignored.
- **Bucket names are global.** Two accounts cannot have the same bucket name, so add a short `name_suffix` (for example part of the account ID). Names longer than 63 characters are refused.
- **Turning versioning off** suspends it; S3 keeps existing object versions.
- **Checking the whole plan.** The [OPA policies](https://github.com/askmohanty/terraform-aws-hardened-modules/tree/main/policies) of this collection verify these settings on any plan, including buckets created outside this module.

## Examples

- [s3-bucket-basic](https://github.com/askmohanty/terraform-aws-hardened-modules/tree/main/examples/s3-bucket-basic): a private bucket with the secure defaults and an archive rule
- [s3-bucket-many](https://github.com/askmohanty/terraform-aws-hardened-modules/tree/main/examples/s3-bucket-many): several buckets from one map, with per-environment values

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9 |
| aws | >= 6.0, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| aws | >= 6.0, < 7.0 |
| terraform | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_ownership_controls.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [terraform_data.guardrails](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_default_tags.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/default_tags) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | What the bucket is for (e.g. `orders-data`). The bucket is named `{Org}-{Environment}-{region_short}-{name}[-{name_suffix}]`, with `Org` and `Environment` read from the AWS provider's `default_tags` and the region from the provider. | `string` | n/a | yes |
| access\_logging | Write server access logs to another bucket. Null turns access logging off. | <pre>object({<br/>    target_bucket = string<br/>    target_prefix = optional(string, "")<br/>  })</pre> | `null` | no |
| force\_destroy | Allow `terraform destroy` to delete a bucket that still contains objects. Refused in `prod`. | `bool` | `false` | no |
| kms\_key\_arn | Customer-managed KMS key for default encryption. When set, uploads that request a different key are denied. When null, the AWS-managed `aws/s3` key is used. | `string` | `null` | no |
| lifecycle\_rules | Extra lifecycle rules: expire or transition objects under a prefix. | <pre>list(object({<br/>    id              = string<br/>    prefix          = optional(string, "")<br/>    expiration_days = optional(number)<br/>    transitions = optional(list(object({<br/>      days          = number<br/>      storage_class = string<br/>    })), [])<br/>  }))</pre> | `[]` | no |
| name\_suffix | Optional suffix appended to the bucket name, for global uniqueness (bucket names are unique across all AWS accounts). For example a short account ID or random string. | `string` | `null` | no |
| noncurrent\_version\_expiration\_days | Delete previous object versions this many days after they stop being current. Null keeps them forever. | `number` | `90` | no |
| policy\_json | Extra bucket policy (JSON from `jsonencode` or `aws_iam_policy_document`), merged with the built-in deny statements (TLS, KMS key). Statements that allow access to everyone (`Principal: "*"`) are refused. | `string` | `null` | no |
| tags | Tags for this bucket only. Stack-wide tags (`Org`, `Environment`, `Owner`, ...) belong in the provider's `default_tags`; `Name`, `Region` and `ManagedBy` are set by the module. | `map(string)` | `{}` | no |
| versioning\_enabled | Keep previous versions of overwritten and deleted objects. Refused as false in `prod`. | `bool` | `true` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| arn | Bucket ARN, for IAM policies (`<arn>` for the bucket, `<arn>/*` for objects). |
| bucket\_regional\_domain\_name | Region-specific domain name, for CloudFront origins and VPC endpoints. |
| id | Bucket name as created. |
| name | Bucket name, built by the naming convention. Known at plan time. |
| region | Region the bucket lives in. |
| tags | Tags this module sets on the bucket (Name, Region, ManagedBy and your `tags`). The provider adds its default\_tags on top. |
<!-- END_TF_DOCS -->

## License

Apache-2.0. See [LICENSE](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/LICENSE).
