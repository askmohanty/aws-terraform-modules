# Architecture

This repository holds **tier-1** Terraform modules for AWS: hardened building blocks that teams and AI agents compose into **tier-2** stacks and deploy through a gated pipeline. The same design applies to the GCP repository.

## Tiers

| Tier | What it is | Who writes it | Where it lives |
|---|---|---|---|
| **Tier 1** | One building block per module (`s3-bucket`, `vpc`, `rds-postgres`, ...): an opinionated, hardened module | This repository | `modules/<name>` |
| **Tier 2** | A stack for one workload or environment, composed **only** of tier-1 modules (e.g. a web service: `vpc` + `ecs-fargate-service` + `rds-postgres` + `s3-bucket`) | Teams or AI agents | Their own repo, from the tier-2 template |

Tier 2 never declares raw `aws_*` resources for something a tier-1 module covers. If a building block is missing, it is added to tier 1 first.

## How a tier-1 module is built

1. **Own code, no module dependencies.** Each module declares its `aws_*` resources directly; the only module call is the internal naming helper. We study how established modules solve the same problem (ordering, edge cases) and write our own implementation, so the Registry lists only the AWS provider as a dependency and every line is ours to audit.
2. **Opinionated, hardened inputs.** A module exposes a small set of inputs and hard-codes the secure settings (callers cannot turn them off). Tests assert those settings on the resources themselves.
3. **Inject naming and tags from the provider.** A stack sets `Org`, `Environment` (and optionally `Owner`, `CostCentre`) once in the AWS provider's `default_tags`. Every module reads them and the provider's region (`aws_default_tags`, `aws_region`), calls `internal/naming`, and needs only a `name`. Resources are named `{org}-{environment}-{region_short}-{name}` (e.g. `acme-prod-euw1-orders-db`); the provider applies the stack tags and the module adds `Name`, `Region` and `ManagedBy`. A provider without `Org` and `Environment` stops the plan.
4. **Guardrails inside the module.** Variable `validation` blocks and `precondition`s on a `terraform_data "guardrails"` resource stop an insecure configuration at plan time; there is no input that disables them.

## Policy as code (OPA)

Module guardrails only protect resources created through the modules. The OPA policies in `policies/` check **the whole plan**, whoever wrote it:

```
terraform plan -out tfplan
terraform show -json tfplan > plan.json
conftest test plan.json -p policies --data policies/data --all-namespaces
```

- Rules are Rego v1, one file per concern, each with unit tests (`*_test.rego`) that include known-bad fixtures.
- `policies/data/config.yaml` holds the organisation's settings: allowed environments, the naming pattern, required tags. Companies override this file, not the rules.
- **Exceptions** are explicit: an entry in `policies/data/exceptions.yaml` names the resource address, the rule, the reason, who approved it and an expiry date. Expired exceptions stop applying automatically.
- CI proves the policies: `opa test` on the rule unit tests, and every module's example is planned against LocalStack (an AWS emulator, so no real account) and must pass the policies. LocalStack is pinned to its last community release (`4`), which runs without a licence; if its AWS coverage falls behind, move to Moto or a licensed LocalStack.

## Deploying tier 2 (agents included)

The reusable workflow `.github/workflows/tier2-deploy.yml` is what tier-2 repos call. An agent (or a person) opens a pull request; it never holds cloud credentials.

| Stage | When | Credentials | Gate |
|---|---|---|---|
| Plan | every PR | GitHub OIDC → read-only plan role | fmt, validate, tflint, `terraform plan` |
| Policy | every PR | none | OPA on the plan JSON; any deny blocks the PR |
| Review | every PR | none | plan summary and policy result posted on the PR |
| Apply | merge to main | GitHub OIDC → deploy role, per environment | `dev` applies automatically; `prod` waits for a required reviewer (GitHub Environments) |

The OIDC roles come from the tier-1 `github-oidc-role` module, scoped to the tier-2 repository and branch.

## Readable by AI agents

- `AGENTS.md` (root): the rules an agent follows when writing tier 2.
- Every module README has the same sections in the same order: *What it creates*, *Security guarantees*, *Usage*, *Composes with*, then the generated inputs/outputs.
- `catalog/modules.json` and `llms.txt` are generated from the modules (terraform-docs JSON), so an agent can list every module, input and output without parsing HCL. CI fails if they are out of date.
- `examples/tier2-web-service/` is a worked tier-2 stack that passes the policies, for agents to follow.

## Versions and releases

- One repository named for the Terraform Registry (`terraform-aws-hardened-modules`), published once as `askmohanty/hardened-modules/aws`. Each tier-1 module is a submodule: `source = "askmohanty/hardened-modules/aws//modules/<name>"` with an exact `version`.
- The whole collection is released together by release-please as `vX.Y.Z`, so modules and the policies that check them always move in lockstep. Versions stay below `1.0.0` until applied against a real account.
- Terraform `>= 1.9` (cross-variable validation); CI tests Terraform 1.9, the latest Terraform and the latest OpenTofu.

## Repository hardening

- `main` is protected by a ruleset: changes only through pull requests, the `CI result` check must pass, commits must be signed, no force-push or deletion, linear history.
- Every GitHub Action is pinned to a commit SHA; downloaded tools are checksum-verified.
- Secret scanning with push protection, private vulnerability reporting, `SECURITY.md`, `CODEOWNERS`.
- OpenSSF Scorecard and a Trivy IaC scan report to the repository's Security tab.
