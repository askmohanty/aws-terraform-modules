# Hardened AWS Terraform modules

[![Terraform Registry](https://img.shields.io/badge/terraform%20registry-askmohanty%2Fhardened--modules%2Faws-623CE4?logo=terraform&logoColor=white)](https://registry.terraform.io/modules/askmohanty/hardened-modules/aws)
[![Version](https://img.shields.io/github/v/release/askmohanty/terraform-aws-hardened-modules?label=version&color=623CE4)](https://registry.terraform.io/modules/askmohanty/hardened-modules/aws/latest)
[![Downloads](https://img.shields.io/terraform/module/dt/askmohanty/hardened-modules/aws?label=downloads)](https://registry.terraform.io/modules/askmohanty/hardened-modules/aws)
[![CI](https://github.com/askmohanty/terraform-aws-hardened-modules/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/askmohanty/terraform-aws-hardened-modules/actions/workflows/ci.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/askmohanty/terraform-aws-hardened-modules/badge)](https://scorecard.dev/viewer/?uri=github.com/askmohanty/terraform-aws-hardened-modules)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue)](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/LICENSE)

Secure-by-default Terraform modules for AWS. Encryption, private access, TLS and logging are always on, every resource follows one naming convention, and OPA policies check the whole plan before anything is created. Tested and ready for teams and AI agents to compose into production stacks.

## Quick start

Set your organisation, environment and region once on the provider; each module then needs only a `name`.

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

module "orders_data" {
  source  = "askmohanty/hardened-modules/aws//modules/s3-bucket"
  version = "0.4.0" # x-release-please-version

  name        = "orders-data" # -> acme-prod-euw1-orders-data-a1b2
  name_suffix = "a1b2"
}
```

```sh
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

## Modules

| Module | What it is | Examples |
|---|---|---|
| [s3-bucket](https://registry.terraform.io/modules/askmohanty/hardened-modules/aws/latest/submodules/s3-bucket) | Private, encrypted, versioned S3 bucket that refuses public access and insecure transport | [basic](https://registry.terraform.io/modules/askmohanty/hardened-modules/aws/latest/examples/s3-bucket-basic), [many from a map](https://registry.terraform.io/modules/askmohanty/hardened-modules/aws/latest/examples/s3-bucket-many) |

Every module is used as `askmohanty/hardened-modules/aws//modules/<name>` with an exact `version`. More modules are on the way: VPC, KMS key, GitHub OIDC role, RDS PostgreSQL, account baseline, EKS, ECS Fargate, Lambda and static site.

## What "hardened" means here

- **Secure settings cannot be switched off.** There is no input to make a bucket public, disable encryption or allow TLS below 1.2. Guardrails stop the plan with a clear message instead.
- **Stricter in production.** With `Environment = "prod"`, modules refuse risky options such as `force_destroy` or disabled versioning.
- **One naming convention.** Names are `{org}-{environment}-{region}-{name}` (`acme-prod-euw1-orders-data`), built from the provider's `default_tags` and region, so names and tags always match where resources really are.
- **Small, opinionated inputs.** Each module exposes only what you need to decide, with safe defaults for the rest.
- **Many from a map.** Every module works with `for_each`, so a list of buckets (or anything else) is one map variable.

## Policy checks for the whole plan

The OPA policies in [`policies/`](https://github.com/askmohanty/terraform-aws-hardened-modules/tree/main/policies) check every resource in a plan, including ones you write yourself: public buckets, unencrypted storage, SSH or RDP open to the internet, `*:*` IAM, long-lived access keys, missing tags, names that break the convention, and `local-exec` provisioners.

```sh
terraform show -json tfplan > plan.json
conftest test plan.json -p policies --data policies/data --all-namespaces
```

Set your environments and required tags in `policies/data/config.yaml`. Exceptions go in `policies/data/exceptions.yaml`, each with a reason, an approver and an expiry date.

## Deploying, including with AI agents

The reusable workflow [`tier2-deploy.yml`](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/.github/workflows/tier2-deploy.yml) plans with short-lived GitHub OIDC credentials, blocks the pull request on any policy failure, posts the plan for review, and applies the exact reviewed plan after merge, with a required approval for prod. [AGENTS.md](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/AGENTS.md), [llms.txt](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/llms.txt) and [catalog/modules.json](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/catalog/modules.json) give AI agents what they need to compose stacks from these modules without bypassing the guardrails.

## Requirements

| Name | Version |
|---|---|
| Terraform | >= 1.9 (OpenTofu also tested) |
| AWS provider | >= 6.0, < 7.0 |

## Documentation

- [Architecture](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/docs/ARCHITECTURE.md): tiers, naming, policies, deployment
- [Security controls](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/docs/SECURITY-CONTROLS.md): mapped to OWASP Top 10:2025, the OWASP CI/CD Top 10 and the OWASP Top 10 for Agentic Applications 2026
- [Contributing](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/CONTRIBUTING.md): the standard every module meets
- [Security policy](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/SECURITY.md): reporting a vulnerability
- [Changelog](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/CHANGELOG.md)

## Status

Versions are `0.x`. Every change is tested offline on Terraform 1.9, the latest Terraform and OpenTofu, and every example is planned against an AWS emulator (LocalStack) and checked by the policies. Modules move to `1.0.0` after being applied in a real AWS account.

## License

[Apache-2.0](https://github.com/askmohanty/terraform-aws-hardened-modules/blob/main/LICENSE)
