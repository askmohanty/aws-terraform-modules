# Naming: many

Names for several related resources at once, with the environment as a variable, so dev and prod get matching names from the same code.

## What it builds

Nothing in AWS: it outputs a map of names, for example in `dev`:

```
orders-queue = "acme-dev-euw1-orders-queue"
orders-dlq   = "acme-dev-euw1-orders-dlq"
orders-topic = "acme-dev-euw1-orders-topic"
```

## Run it

```sh
terraform init
terraform plan                          # dev names
terraform plan -var environment=prod    # prod names
```

## Use it in your own stack

```hcl
module "name" {
  source   = "askmohanty/hardened-modules/aws//modules/naming"
  version  = "0.2.0" # x-release-please-version
  for_each = toset(["orders-queue", "orders-dlq"])

  org         = "acme"
  environment = var.environment
  region      = var.region
  name        = each.key
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| name | ../../modules/naming | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| environment | Environment, plugged in per environment (dev, test, staging or prod). | `string` | `"dev"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| names | Conventional name per resource. |
<!-- END_TF_DOCS -->
