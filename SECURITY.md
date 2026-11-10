# Security policy

## Reporting a vulnerability

Report vulnerabilities privately through GitHub: **Security → Report a vulnerability** on this repository. Please do not open a public issue.

Include the module and version, what an attacker could do, and steps to reproduce. You will get an acknowledgement within 5 working days and a fix or mitigation plan within 30 days for confirmed issues.

## Scope

- A module input or default that creates an insecure resource.
- A guardrail (validation, precondition or OPA policy) that can be bypassed.
- A weakness in the CI, release or deploy workflows.

## Supported versions

Only the latest release of each module receives fixes.

## How this repository is protected

See [docs/SECURITY-CONTROLS.md](docs/SECURITY-CONTROLS.md).
