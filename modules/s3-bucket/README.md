# s3-bucket

A private, encrypted, versioned S3 bucket that refuses public access and insecure transport.

## What it creates

The bucket, its ownership controls (ACLs disabled), public access block, versioning, KMS default encryption, lifecycle rules, an optional access-logging target and a bucket policy. It wraps [terraform-aws-modules/s3-bucket](https://github.com/terraform-aws-modules/terraform-aws-s3-bucket) v5.17.0, pinned to commit `9afa4fc8`.

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
module "orders_data" {
  source = "git::https://github.com/askmohanty/aws-terraform-modules.git//modules/s3-bucket?ref=s3-bucket/v0.1.0" # x-release-please-version

  context = {
    org         = "acme"
    environment = "prod"
    region      = "eu-west-1"
    owner       = "orders-team"
  }

  name        = "orders-data"   # -> acme-prod-euw1-orders-data-<suffix>
  name_suffix = "a1b2"          # bucket names are global; add a suffix to avoid collisions
  kms_key_arn = module.orders_key.arn
}
```

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
| terraform | n/a |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| bucket | git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git | 9afa4fc8c8f1e0b3fd913474c1bef8d0c454b235 |
| naming | ../naming | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [terraform_data.guardrails](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| context | Naming and tagging context shared by every module in a stack. See `modules/naming`. | <pre>object({<br/>    org                  = string<br/>    environment          = string<br/>    region               = string<br/>    owner                = optional(string)<br/>    cost_centre          = optional(string)<br/>    extra_tags           = optional(map(string), {})<br/>    allowed_environments = optional(list(string), ["dev", "test", "staging", "prod"])<br/>  })</pre> | n/a | yes |
| name | What the bucket is for (e.g. `orders-data`). The bucket is named `{org}-{environment}-{region_short}-{name}[-{name_suffix}]`. | `string` | n/a | yes |
| access\_logging | Write server access logs to another bucket. Null turns access logging off. | <pre>object({<br/>    target_bucket = string<br/>    target_prefix = optional(string, "")<br/>  })</pre> | `null` | no |
| force\_destroy | Allow `terraform destroy` to delete a bucket that still contains objects. Refused in `prod`. | `bool` | `false` | no |
| kms\_key\_arn | Customer-managed KMS key for default encryption. When set, uploads that request a different key are denied. When null, the AWS-managed `aws/s3` key is used. | `string` | `null` | no |
| lifecycle\_rules | Extra lifecycle rules: expire or transition objects under a prefix. | <pre>list(object({<br/>    id              = string<br/>    prefix          = optional(string, "")<br/>    expiration_days = optional(number)<br/>    transitions = optional(list(object({<br/>      days          = number<br/>      storage_class = string<br/>    })), [])<br/>  }))</pre> | `[]` | no |
| name\_suffix | Optional suffix appended to the bucket name, for global uniqueness (bucket names are unique across all AWS accounts). For example a short account ID or random string. | `string` | `null` | no |
| noncurrent\_version\_expiration\_days | Delete previous object versions this many days after they stop being current. Null keeps them forever. | `number` | `90` | no |
| policy\_json | Extra bucket policy (JSON from `jsonencode` or `aws_iam_policy_document`), merged with the built-in deny statements (TLS, KMS key). Statements that allow access to everyone (`Principal: "*"`) are refused. | `string` | `null` | no |
| tags | Extra tags. The standard naming tags always win. | `map(string)` | `{}` | no |
| versioning\_enabled | Keep previous versions of overwritten and deleted objects. Refused as false in `prod`. | `bool` | `true` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| arn | Bucket ARN, for IAM policies (`<arn>` for the bucket, `<arn>/*` for objects). |
| bucket\_regional\_domain\_name | Region-specific domain name, for CloudFront origins and VPC endpoints. |
| id | Bucket name as created. |
| name | Bucket name, built by the naming convention. Known at plan time. |
| region | Region the bucket lives in. |
| tags | Tags applied to the bucket. |
<!-- END_TF_DOCS -->
