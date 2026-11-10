# terraform-aws-hardened-modules

Hardened, tested Terraform modules for AWS that companies can use as their tier-1 building blocks, with policy-as-code guardrails and a gated pipeline that AI agents can use to compose and deploy tier-2 stacks safely.

- **Secure by default, not by option.** Encryption, private access, TLS and logging are on and cannot be turned off from the module inputs.
- **Built on proven open source.** Where a well-maintained [terraform-aws-modules](https://github.com/terraform-aws-modules) module exists, these modules wrap it at a pinned commit and change its behaviour: fewer inputs, hardened defaults, guardrails.
- **One naming convention everywhere.** `{org}-{environment}-{region}-{name}`, built by every module from the provider's `default_tags` and region, so a module call needs only a `name`.
- **Policy as code.** OPA rules check the whole Terraform plan, whoever wrote it, with reviewed and expiring exceptions.
- **Written for agents too.** [AGENTS.md](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/AGENTS.md), [llms.txt](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/llms.txt) and [catalog/modules.json](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/catalog/modules.json) let an AI agent compose correct tier-2 stacks.

## Modules

| Module | What it is | Use it as | Examples |
|---|---|---|---|
| [s3-bucket](https://registry.terraform.io/modules/askmohanty/hardened-modules/aws/latest/submodules/s3-bucket) | Private, encrypted, versioned S3 bucket | `askmohanty/hardened-modules/aws//modules/s3-bucket` | [basic](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/examples/s3-bucket-basic), [many from a map](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/examples/s3-bucket-many) |
| [naming](https://registry.terraform.io/modules/askmohanty/hardened-modules/aws/latest/submodules/naming) | Resource names and standard tags, used by every module | `askmohanty/hardened-modules/aws//modules/naming` | [basic](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/examples/naming-basic), [many](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/examples/naming-many) |

More modules are being added; see [catalog/modules.json](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/catalog/modules.json) for the current list.

## Using a module

Modules are published on the Terraform Registry as one collection, [`askmohanty/hardened-modules/aws`](https://registry.terraform.io/modules/askmohanty/hardened-modules/aws). Set the stack's `Org` and `Environment` once in the provider's `default_tags`; every module reads them and the provider's region to build names. Pin an exact version:

```hcl
provider "aws" {
  region = "eu-west-1"
  default_tags {
    tags = { Org = "acme", Environment = "prod", Owner = "orders-team" }
  }
}

module "orders_data" {
  source  = "askmohanty/hardened-modules/aws//modules/s3-bucket"
  version = "0.1.0" # x-release-please-version
  name   = "orders-data" # -> acme-prod-euw1-orders-data
}
```

## Checking a plan against the policies

```sh
terraform plan -out tfplan
terraform show -json tfplan > plan.json
conftest test plan.json -p policies --data policies/data --all-namespaces
```

Copy `policies/data/config.yaml` to set your organisation's environments and required tags. Exceptions go in `policies/data/exceptions.yaml`, each with a reason, an approver and an expiry date.

## Documentation

- [docs/ARCHITECTURE.md](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/docs/ARCHITECTURE.md): tiers, wrapping, naming, policies, deployment
- [docs/SECURITY-CONTROLS.md](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/docs/SECURITY-CONTROLS.md): controls mapped to OWASP Top 10:2025, the OWASP CI/CD Top 10 and the OWASP Top 10 for Agentic Applications 2026
- [CONTRIBUTING.md](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/CONTRIBUTING.md): the standard every module meets
- [SECURITY.md](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/SECURITY.md): reporting a vulnerability

## Status

Modules are at `0.x`: tested offline on Terraform 1.9, the latest Terraform and OpenTofu, and planned against LocalStack with the policies on every change. They move to `1.0.0` after being applied in a real AWS account.

Licensed under [Apache-2.0](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/LICENSE).
