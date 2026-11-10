# terraform-aws-secure

Hardened, tested Terraform modules for AWS that companies can use as their tier-1 building blocks, with policy-as-code guardrails and a gated pipeline that AI agents can use to compose and deploy tier-2 stacks safely.

- **Secure by default, not by option.** Encryption, private access, TLS and logging are on and cannot be turned off from the module inputs.
- **Built on proven open source.** Where a well-maintained [terraform-aws-modules](https://github.com/terraform-aws-modules) module exists, these modules wrap it at a pinned commit and change its behaviour: fewer inputs, hardened defaults, guardrails.
- **One naming convention everywhere.** `{org}-{environment}-{region}-{name}`, built by every module from the provider's `default_tags` and region, so a module call needs only a `name`.
- **Policy as code.** OPA rules check the whole Terraform plan, whoever wrote it, with reviewed and expiring exceptions.
- **Written for agents too.** [AGENTS.md](AGENTS.md), [llms.txt](llms.txt) and [catalog/modules.json](catalog/modules.json) let an AI agent compose correct tier-2 stacks.

## Modules

| Module | What it is |
|---|---|
| [naming](modules/naming) | Names and standard tags; used by every other module |
| [s3-bucket](modules/s3-bucket) | Private, encrypted, versioned S3 bucket |

More modules are being added; see [catalog/modules.json](catalog/modules.json) for the current list.

## Using a module

Modules are published on the Terraform Registry as one collection, [`askmohanty/secure/aws`](https://registry.terraform.io/modules/askmohanty/secure/aws). Set the stack's `Org` and `Environment` once in the provider's `default_tags`; every module reads them and the provider's region to build names. Pin an exact version:

```hcl
provider "aws" {
  region = "eu-west-1"
  default_tags {
    tags = { Org = "acme", Environment = "prod", Owner = "orders-team" }
  }
}

module "orders_data" {
  source  = "askmohanty/secure/aws//modules/s3-bucket"
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

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): tiers, wrapping, naming, policies, deployment
- [docs/SECURITY-CONTROLS.md](docs/SECURITY-CONTROLS.md): controls mapped to OWASP Top 10:2025, the OWASP CI/CD Top 10 and the OWASP Top 10 for Agentic Applications 2026
- [CONTRIBUTING.md](CONTRIBUTING.md): the standard every module meets
- [SECURITY.md](SECURITY.md): reporting a vulnerability

## Status

Modules are at `0.x`: tested offline on Terraform 1.9, the latest Terraform and OpenTofu, and planned against LocalStack with the policies on every change. They move to `1.0.0` after being applied in a real AWS account.

Licensed under [Apache-2.0](LICENSE).
