# S3 bucket: basic

One private, encrypted, versioned S3 bucket with an archive rule, using the module's secure defaults.

## What it builds

- Bucket `acme-dev-euw1-orders-data-ex1`, named from the provider's `default_tags` (`Org`, `Environment`) and region.
- Public access blocked, ACLs disabled, KMS encryption, TLS 1.2+ required by the bucket policy, versioning on.
- Lifecycle: objects under `exports/` move to `STANDARD_IA` after 30 days; old versions expire after 90 days; unfinished uploads are cleaned up after 7 days.

## Run it

Set your own `Org`, `Environment`, `Owner` and region in the provider block, and change `name_suffix` (bucket names are global).

```sh
terraform init
terraform plan -out tfplan

# Optional: check the plan against the OPA policies before applying
terraform show -json tfplan > plan.json
conftest test plan.json -p ../../policies --data ../../policies/data --all-namespaces

terraform apply tfplan
```

Remove it with `terraform destroy` (outside `prod`, add `force_destroy = true` first if the bucket holds objects).

## Use it in your own stack

```hcl
module "orders_data" {
  source  = "askmohanty/hardened-modules/aws//modules/s3-bucket"
  version = "0.3.0" # x-release-please-version

  name        = "orders-data"
  name_suffix = "a1b2"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9 |
| aws | >= 6.44, < 7.0 |

## Providers

No providers.

## Resources

No resources.

## Inputs

No inputs.

## Outputs

| Name | Description |
| ---- | ----------- |
| bucket\_arn | ARN of the bucket, for IAM policies. |
| bucket\_name | Name of the bucket, built from the naming convention. |
<!-- END_TF_DOCS -->
