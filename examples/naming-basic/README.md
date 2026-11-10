# Naming: basic

Builds a conventional name and the standard tags for a resource that no module covers yet, so it still follows `{org}-{environment}-{region}-{name}`.

## What it builds

Nothing in AWS: it outputs the name `acme-dev-euw1-orders-queue` and the tags `Name`, `Org`, `Environment`, `Region`, `ManagedBy` and `Owner`, for you to put on your own resource.

## Run it

```sh
terraform init
terraform plan   # shows the name and tags as outputs
```

## Use it in your own stack

```hcl
module "queue_name" {
  source  = "askmohanty/hardened-modules/aws//modules/naming"
  version = "0.2.0" # x-release-please-version

  org         = "acme"
  environment = "prod"
  region      = "eu-west-1"
  name        = "orders-queue"
}

resource "aws_sqs_queue" "orders" {
  name = module.queue_name.id
  tags = module.queue_name.tags
}
```

Every other module in this collection already applies the convention itself; you only need `naming` for resources outside the collection.

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

No inputs.

## Outputs

| Name | Description |
| ---- | ----------- |
| name | The conventional name for your resource. |
| tags | Standard tags to put on your resource. |
<!-- END_TF_DOCS -->
