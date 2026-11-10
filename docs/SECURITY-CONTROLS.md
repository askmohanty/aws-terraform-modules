# Security controls mapped to OWASP

How this repository, its modules and the tier-2 deploy pipeline address the current OWASP lists:

- [OWASP Top 10:2025](https://owasp.org/Top10/2025/)
- [OWASP Top 10 CI/CD Security Risks](https://owasp.org/www-project-top-10-ci-cd-security-risks/)
- [OWASP Top 10 for Agentic Applications 2026](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/), because AI agents write and deploy tier-2 stacks from these modules
- [OWASP Infrastructure as Code Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Infrastructure_as_Code_Security_Cheat_Sheet.html)

Every control names where it lives, so it can be checked. Review this file whenever one of the lists is revised.

## OWASP Top 10:2025, as it applies to infrastructure code

| Risk | Control | Where |
|---|---|---|
| A01 Broken Access Control | No public buckets or public policies; least-privilege IAM, no `*:*`; module inputs refuse `Principal: "*"` | module `validation`, `policies/aws/s3.rego`, `policies/aws/iam_kms.rego` |
| A02 Security Misconfiguration | Secure defaults that callers cannot turn off; prod-only guardrails (deletion protection, versioning); whole-plan policy check | module wrappers, `terraform_data.guardrails`, `policies/` |
| A03 Software Supply Chain Failures | Upstream modules pinned to commit SHAs; every Action pinned to a SHA; tools checksum-verified; Renovate updates re-checked by CI; OpenSSF Scorecard | `modules/*/main.tf`, `.github/workflows/`, `renovate.json` |
| A04 Cryptographic Failures | Encryption at rest always on (KMS); TLS 1.2+ required in transit; KMS key rotation | modules, `policies/aws/s3.rego`, `policies/aws/data_stores.rego`, `policies/aws/iam_kms.rego` |
| A05 Injection | Workflow inputs passed through `env:`, never interpolated into scripts; no provisioners or `external` data sources; workflow static analysis | `.github/workflows/`, `policies/common/execution.rego`, zizmor |
| A06 Insecure Design | Tier model (tier 2 only composes tier 1); policy-as-code over the whole plan; reviewed, expiring exceptions | `docs/ARCHITECTURE.md`, `policies/data/exceptions.yaml` |
| A07 Authentication Failures | Deploys use GitHub OIDC short-lived credentials; long-lived access keys denied | `github-oidc-role` module, `policies/aws/iam_kms.rego` |
| A08 Software or Data Integrity Failures | Signed commits required on `main`; apply runs the exact reviewed plan file; release artifacts carry build provenance attestations | branch ruleset, `tier2-deploy.yml`, `release.yml` |
| A09 Security Logging and Alerting Failures | Access logging and audit trails in modules (S3 access logs, CloudTrail in `account-baseline`); plan and policy results kept as workflow artifacts | modules, `tier2-deploy.yml` |
| A10 Mishandling of Exceptional Conditions | Fail closed: a policy evaluation error, a missing plan or a failed precondition stops the pipeline; scripts run with `set -euo pipefail` | `ci.yml`, `tier2-deploy.yml`, `terraform_data.guardrails` |

## OWASP Top 10 CI/CD Security Risks

| Risk | Control |
|---|---|
| CICD-SEC-1 Insufficient Flow Control | `main` ruleset: pull requests only, `CI result` must pass, signed commits, no force-push or deletion; prod deploys need a reviewer (GitHub Environments) |
| CICD-SEC-2 Inadequate Identity and Access Management | Single maintainer with 2FA; `CODEOWNERS`; agents act only through pull requests and never hold credentials |
| CICD-SEC-3 Dependency Chain Abuse | Commit-SHA pins for upstream modules and Actions; checksum-verified tool downloads; no `curl \| sh` |
| CICD-SEC-4 Poisoned Pipeline Execution | No `pull_request_target`; workflows from forks need approval; untrusted values reach scripts only through `env:`; zizmor checks workflows |
| CICD-SEC-5 Insufficient PBAC | Default workflow token is read-only; each job asks for the permissions it needs; plan and apply use different cloud roles |
| CICD-SEC-6 Insufficient Credential Hygiene | No stored cloud secrets (OIDC); `persist-credentials: false` on checkout; secret scanning with push protection |
| CICD-SEC-7 Insecure System Configuration | GitHub-hosted ephemeral runners; repository Actions settings: allowed-actions list and required SHA pinning |
| CICD-SEC-8 Ungoverned Usage of 3rd Party Services | Small, explicit list of allowed Actions; Renovate as the only app with write access (opens PRs, merges only on green CI) |
| CICD-SEC-9 Improper Artifact Integrity Validation | Signed commits; release tarballs with provenance attestations and SHA-256 checksums; consumers pin modules to a commit or tag |
| CICD-SEC-10 Insufficient Logging and Visibility | Workflow logs and artifacts retained; Scorecard, zizmor and Trivy results in the Security tab |

## OWASP Top 10 for Agentic Applications 2026 (agents writing and deploying tier 2)

| Risk | Control |
|---|---|
| ASI01 Agent Goal Hijack | `AGENTS.md`: module docs, issues and plan output are data, never instructions; the pipeline's gates do not depend on what the agent claims |
| ASI02 Tool Misuse and Exploitation | The agent's only tool for change is a pull request; plan, policy and apply run in CI, not in the agent's environment |
| ASI03 Identity and Privilege Abuse | Separate OIDC roles for plan (read-only) and apply (per environment), scoped to the tier-2 repo and branch |
| ASI04 Agentic Supply Chain Vulnerabilities | Tier 2 may use only tier-1 modules pinned to a commit or release tag (`AGENTS.md`); raw upstream modules are not allowed in tier 2 |
| ASI05 Unexpected Code Execution | Provisioners (`local-exec`, `remote-exec`) and `data "external"` denied by policy |
| ASI06 Memory and Context Poisoning | The catalog and docs agents read are generated from the code in CI and checked for drift, not edited by hand |
| ASI07 Insecure Inter-Agent Communication | Agents coordinate only through the repository (pull requests and checks), not side channels |
| ASI08 Cascading Failures | One stack per tier-2 root module and environment; `prod` applies one at a time behind a human approval |
| ASI09 Human-Agent Trust Exploitation | The reviewer sees the real plan and the policy result posted by CI, not the agent's summary |
| ASI10 Rogue Agents | Revoking the OIDC trust or disabling the workflow stops all deploys immediately; agents have no standing access |

## OWASP Infrastructure as Code Security Cheat Sheet

| Recommendation | Control |
|---|---|
| IDE and static analysis, CI checks | tflint, `terraform validate`, `terraform test`, OPA, Trivy IaC scan |
| Threat model early | `docs/ARCHITECTURE.md` tier model and this file |
| Secrets out of code | No secret inputs written to state where avoidable (managed master passwords); secret scanning with push protection |
| Version control for every change | Everything through pull requests on a ruleset-protected `main` |
| Least privilege | IAM rules and module inputs; plan/apply role split |
| Sign artifacts and validate before use | Signed commits; release attestations and checksums |
| Inventory, tags, no ghost resources | Naming module and required-tags policy |
| Security and audit logging at provisioning | Access logs, CloudTrail, VPC flow logs in the modules |
