# naming

Builds resource names (`{org}-{environment}-{region_short}-{name}`) and the standard tag set every module applies.

## What it creates

Nothing: it computes values. Every other module calls it internally with `Org` and `Environment` from the AWS provider's `default_tags` and the provider's region, so tier-2 code rarely calls it directly. Use it directly only for resources that no tier-1 module covers yet, so they follow the same convention.

## Security guarantees

- Names are lowercase, predictable and contain the environment, so the `naming` OPA policy can verify them.
- The standard tags (`Name`, `Org`, `Environment`, `Region`, `ManagedBy`, plus `Owner` and `CostCentre` when set) always win over caller-supplied tags, so they cannot be spoofed.
- `environment` must be in `allowed_environments`; keep that list in step with `policies/data/config.yaml`.

## Usage

```hcl
module "name" {
  source  = "askmohanty/secure/aws//modules/naming"
  version = "0.1.0" # x-release-please-version

  org         = "acme"
  environment = "prod"
  region      = "eu-west-1"
  name        = "orders-db"   # -> acme-prod-euw1-orders-db
  owner       = "orders-team"
}
```

## Composes with

| Use this output | As this input |
|---|---|
| `id` | the `name`/`identifier` of a resource no tier-1 module covers yet |
| `tags` | the `tags` of that resource |

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9 |

## Providers

No providers.

## Modules

No modules.

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| environment | Environment, the second part of every name. Must be one of `allowed_environments`. | `string` | n/a | yes |
| name | What the resource is for, the last part of the name (e.g. `orders-db`). | `string` | n/a | yes |
| org | Short organisation code, the first part of every name (e.g. `acme`). | `string` | n/a | yes |
| region | AWS region the resources live in (e.g. `eu-west-1`). Shortened in names: `eu-west-1` becomes `euw1`. | `string` | n/a | yes |
| allowed\_environments | Environments this organisation uses. Keep it in step with the OPA policy data (`policies/data/config.yaml`). | `list(string)` | <pre>[<br/>  "dev",<br/>  "test",<br/>  "staging",<br/>  "prod"<br/>]</pre> | no |
| cost\_centre | Cost centre, added as the `CostCentre` tag. | `string` | `null` | no |
| extra\_tags | Additional tags. The standard tags (`Name`, `Org`, `Environment`, `Region`, `ManagedBy`, `Owner`, `CostCentre`) always win over these. | `map(string)` | `{}` | no |
| owner | Team or person accountable for the resource, added as the `Owner` tag. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| id | Full resource name: `{org}-{environment}-{region_short}-{name}`, e.g. `acme-prod-euw1-orders-db`. |
| region\_short | Short region code used in names, e.g. `euw1`. |
| tags | Tags every resource gets: `extra_tags` overlaid by the standard tags. |
<!-- END_TF_DOCS -->
