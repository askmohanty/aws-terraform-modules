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
├── version.txt        # managed by release-please
├── examples/basic/    # a runnable root module using the module with a provider block
│   └── main.tf
└── tests/
    └── *.tftest.hcl   # offline tests with mocked providers
```

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

- Conventional commits scoped to the module: `feat(s3-bucket): add replication`, `fix(vpc): ...`. A change touching several modules uses one commit per module where practical.
- [release-please](https://github.com/googleapis/release-please) opens a release PR per change set; merging it tags `<module>/vX.Y.Z` and publishes a GitHub Release with the module's changelog.
- Modules start at `0.1.0`. They reach `1.0.0` once they have been applied against a real account, not only tested offline.

## Checking a module locally

```sh
cd modules/<name>
terraform fmt -check -recursive
terraform init -backend=false && terraform validate
terraform test
tflint --init --config ../../.tflint.hcl && tflint --config ../../.tflint.hcl
terraform-docs -c ../../.terraform-docs.yml .
(cd examples/basic && terraform init -backend=false && terraform validate)
```
