# S3 bucket: many from a map

Several buckets from one map variable, with the environment and region plugged in per environment. This is the usual tier-2 pattern: add a bucket by adding a map entry, not by copying a module block.

## What it builds

Three buckets, each with the module's secure defaults and its own lifecycle:

| Key (`name`) | Bucket (in `dev`, `eu-west-1`) | Lifecycle |
|---|---|---|
| `orders-data` | `acme-dev-euw1-orders-data-ex1` | defaults |
| `exports` | `acme-dev-euw1-exports-ex1` | objects expire after 30 days |
| `audit-logs` | `acme-dev-euw1-audit-logs-ex1` | to `GLACIER_IR` after 90 days |

## Run it

Keep one values file per environment and pass the right one; the same code is promoted from dev to prod.

```hcl
# environments/prod.tfvars
environment = "prod"
region      = "eu-west-1"
buckets = {
  orders-data = {}
  exports     = { lifecycle_rules = [{ id = "expire", expiration_days = 30 }] }
}
```

```sh
terraform init
terraform plan -var-file=environments/prod.tfvars -out tfplan
terraform apply tfplan
```

In prod the module refuses `force_destroy` and disabled versioning, whatever the map says.

## Use it in your own stack

```hcl
module "bucket" {
  source   = "askmohanty/hardened-modules/aws//modules/s3-bucket"
  version  = "0.3.0" # x-release-please-version
  for_each = var.buckets

  name               = each.key
  versioning_enabled = each.value.versioning_enabled
  lifecycle_rules    = each.value.lifecycle_rules
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9 |
| aws | >= 6.0, < 7.0 |

## Providers

No providers.

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| buckets | Buckets to create, keyed by purpose. | <pre>map(object({<br/>    versioning_enabled = optional(bool, true)<br/>    lifecycle_rules = optional(list(object({<br/>      id              = string<br/>      prefix          = optional(string, "")<br/>      expiration_days = optional(number)<br/>      transitions = optional(list(object({<br/>        days          = number<br/>        storage_class = string<br/>      })), [])<br/>    })), [])<br/>  }))</pre> | <pre>{<br/>  "audit-logs": {<br/>    "lifecycle_rules": [<br/>      {<br/>        "id": "archive",<br/>        "transitions": [<br/>          {<br/>            "days": 90,<br/>            "storage_class": "GLACIER_IR"<br/>          }<br/>        ]<br/>      }<br/>    ]<br/>  },<br/>  "exports": {<br/>    "lifecycle_rules": [<br/>      {<br/>        "expiration_days": 30,<br/>        "id": "expire"<br/>      }<br/>    ]<br/>  },<br/>  "orders-data": {}<br/>}</pre> | no |
| environment | Plugged in per environment (environments/<env>.tfvars or TF\_VAR\_environment). | `string` | `"dev"` | no |
| region | AWS region for the stack, plugged in per environment. | `string` | `"eu-west-1"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| bucket\_arns | Bucket ARN per map key. |
| bucket\_names | Bucket name per map key. |
<!-- END_TF_DOCS -->
