# Module standard

Every module in this repository meets this standard. A pull request that adds or changes a module is reviewed against it.

## Layout

```
modules/<name>/
├── versions.tf        # required_version and required_providers only; no provider blocks
├── variables.tf       # every input: type, description, validation where values are constrained
├── main.tf            # resources (split into more files only when main.tf passes ~300 lines)
├── outputs.tf         # every output has a description
├── README.md          # purpose, security defaults, usage, generated inputs/outputs
└── tests/
    └── *.tftest.hcl   # offline tests with mocked providers
```

Examples live at the top level, where the Terraform Registry lists them, one directory per example:

```
examples/<name>-basic/   # the module with its defaults: README.md + main.tf
examples/<name>-many/    # many instances from a map, environment values as variables
```

Each example has a README with what it builds, how to run it, and generated inputs and outputs.

## Versions

- `required_version = ">= 1.9"`. CI tests every module on Terraform 1.9 (the minimum), the latest Terraform and the latest OpenTofu.
- `hashicorp/aws` constrained to `">= 6.0, < 7.0"` (widen the lower bound only when the module needs a newer feature, and say which).
- Modules never configure providers or backends. The caller does.

## Secure by default

Defaults must be the safe choice; anything less safe is an explicit opt-in with a clear variable name.

- Encryption at rest on, with a customer-managed KMS key supported (`kms_key_arn`), never optional to turn off.
- No public access unless the module's purpose is public (for example a CDN origin), and then only through the narrowest mechanism.
- TLS required in transit (bucket and queue policies deny non-TLS requests).
- Logging and audit trails on where the service offers them.
- IAM: least privilege, no `*` actions on `*` resources, trust policies scoped to exact principals and conditions.
- Stateful resources get `deletion_protection` (or equivalent) on by default.
- Every resource that accepts tags gets `var.tags`.

## Many instances from a map

Tier-2 stacks usually create several of a thing from one map (`for_each` on the module call), with environment values plugged in per environment. Every module therefore:

- works with `for_each` and `count` on the module call (no provider or backend blocks inside, no global names that collide between instances);
- documents a map-driven usage in its README;
- has `examples/<name>-many/` doing exactly that, with `environment` and `region` as variables. CI validates, documents and policy-checks every example.

## Naming from the provider

Every module takes a `name` and reads the stack's facts from the provider: `data "aws_default_tags"` for `Org` and `Environment`, `data "aws_region"` for the region. It calls `internal/naming` for the resource name, sets only `Name`, `Region` and `ManagedBy` (plus caller `tags`, minus any stack tag keys) on resources, and refuses the plan when `Org` or `Environment` is missing. Tests pin both data sources with `override_data`.

## Inputs and outputs

- `snake_case` names, a `description` on every variable and output, and a precise `type` (no bare `any` unless the shape genuinely varies).
- `validation` blocks for constrained values (names, ranges, enums, CIDRs, ARNs).
- Prefer a few well-named variables over exposing every resource argument. A module is an opinion.
- Output what callers need to wire modules together (IDs, ARNs, names, endpoints), never secrets.

## Policies are built with `jsonencode`

Build IAM and resource policies with `jsonencode()` from locals, not the `aws_iam_policy_document` data source. Mocked providers return random strings for data-source attributes, so `jsonencode` is what lets the tests assert the exact statements.

## Tests

Tests run offline with `mock_provider "aws" {}`. No AWS account or credentials are needed. Each module's tests cover at least:

1. **Defaults are secure**: assert the security-relevant arguments on the default configuration.
2. **Each optional feature** on and off.
3. **Each validation rule**: a run with `expect_failures` for every `validation` block.

Use `command = apply` when an assertion needs computed values (mocked apply creates nothing real). Use `override_data` for any data source the module reads.

## Commits and releases

- Conventional commits scoped to the module: `feat(s3-bucket): add replication`, `fix(vpc): ...`.
- Pull requests are squash-merged, so the **PR title** becomes the commit release-please reads: write it as a conventional commit (`feat(s3-bucket): ...`, `fix: ...`, `docs: ...`).
- The collection is released as one unit, published on the Terraform Registry as `askmohanty/hardened-modules/aws` (modules are used as `askmohanty/hardened-modules/aws//modules/<name>`). [release-please](https://github.com/googleapis/release-please) opens a release PR; merging it tags `vX.Y.Z`, which the Registry publishes, and attaches a checksummed, attested archive to the GitHub Release.
- Versions stay below `1.0.0` until the modules have been applied in a real account, not only tested offline.

## Checking a module locally

```sh
cd modules/<name>
terraform fmt -check -recursive
terraform init -backend=false && terraform validate
terraform test
tflint --init --config ../../.tflint.hcl && tflint --config ../../.tflint.hcl
terraform-docs -c ../../.terraform-docs.yml .
(cd ../../examples/<name>-basic && terraform init -backend=false && terraform validate)
```
