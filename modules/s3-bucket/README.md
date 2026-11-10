# s3-bucket

A private, encrypted, versioned S3 bucket that refuses public access and insecure transport.

## What it creates

The bucket, its ownership controls (ACLs disabled), public access block, versioning, KMS default encryption, lifecycle rules, an optional access-logging target and a bucket policy.

## Security guarantees

Callers cannot turn these off:

- All four public access block settings on; ACLs disabled (`BucketOwnerEnforced`).
- Default encryption with KMS (the `aws/s3` key, or `kms_key_arn`). With `kms_key_arn` set, uploads naming another key are denied.
- The bucket policy denies requests without TLS and TLS older than 1.2.
- A `policy_json` that allows access to everyone (`Principal: "*"`, including inside an `AWS` list) is refused.
- In `prod`: `force_destroy` is refused and versioning cannot be turned off.
- Incomplete multipart uploads are cleaned up after 7 days.

## Usage

```hcl
provider "aws" {
  region = "eu-west-1"
  default_tags {
    tags = { Org = "acme", Environment = "prod", Owner = "orders-team" }
  }
}

module "orders_data" {
  source  = "askmohanty/hardened-modules/aws//modules/s3-bucket"
  version = "0.2.0" # x-release-please-version

  name        = "orders-data"   # -> acme-prod-euw1-orders-data-a1b2
  name_suffix = "a1b2"          # bucket names are global; add a suffix to avoid collisions
  kms_key_arn = module.orders_key.arn
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
  source  = "askmohanty/hardened-modules/aws//modules/s3-bucket"
  version = "0.2.0" # x-release-please-version
  for_each = var.buckets

  name               = each.key              # orders-data -> acme-prod-euw1-orders-data
  versioning_enabled = each.value.versioning_enabled
  lifecycle_rules    = each.value.lifecycle_rules
}
```

See [examples/s3-bucket-many](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/examples/s3-bucket-many/main.tf).

## Composes with

| Use this output | As this input |
|---|---|
| `kms-key.arn` | `kms_key_arn` here |
| `arn` | IAM policy `Resource` in `github-oidc-role`, `lambda-function`, `ecs-fargate-service` (`<arn>` and `<arn>/*`) |
| `bucket_regional_domain_name` | origin in `static-site` |
| `name` | `access_logging.target_bucket` of another `s3-bucket` (a dedicated log bucket) |

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9 |
| aws | >= 6.44, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| aws | >= 6.44, < 7.0 |
| terraform | n/a |

## Resources

| Name | Type |
| ---- | ---- |
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
