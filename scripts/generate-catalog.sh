#!/usr/bin/env bash
# Generate the machine-readable module catalog that AI agents read before writing tier 2:
#   catalog/modules.json  every module with its summary, inputs, outputs and source address
#   llms.txt              a short index pointing agents to AGENTS.md, the catalog and each README
# CI fails when the committed files differ from what this script produces.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
repo="askmohanty/terraform-aws-hardened-modules"
cd "$root"
mkdir -p catalog

modules=()
for dir in modules/*/; do
  name="$(basename "$dir")"
  # The README's second non-empty line is the one-sentence summary (see CONTRIBUTING.md).
  summary="$(grep -v '^\s*$' "$dir/README.md" | sed -n '2p')"
  terraform-docs -c scripts/terraform-docs-json.yml json "$dir" | jq --arg name "$name" --arg summary "$summary" --arg repo "$repo" '{
      name: $name,
      summary: $summary,
      source: "askmohanty/hardened-modules/aws//modules/\($name)",
      version: "pin the latest release exactly: https://registry.terraform.io/modules/askmohanty/hardened-modules/aws",
      inputs: [.inputs[] | {name, type, required, default, description}],
      outputs: [.outputs[] | {name, description}],
      calls: [.modules[]? | {name, source}]
    }' > "catalog/.$name.json"
  modules+=("catalog/.$name.json")
done

jq -s '{repository: "https://github.com/'"$repo"'", tier: 1, modules: .}' "${modules[@]}" > catalog/modules.json
rm -f "${modules[@]}"

{
  echo "# terraform-aws-hardened-modules"
  echo
  echo "> Hardened tier-1 Terraform modules for AWS. Compose them into tier-2 stacks; never bypass their guardrails."
  echo
  echo "Read first: [AGENTS.md](AGENTS.md) (rules for writing and deploying tier 2), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/SECURITY-CONTROLS.md](docs/SECURITY-CONTROLS.md)."
  echo "Machine-readable catalog of every input and output: [catalog/modules.json](catalog/modules.json)."
  echo
  echo "## Modules"
  echo
  jq -r '.modules[] | "- [\(.name)](modules/\(.name)/README.md): \(.summary)"' catalog/modules.json
} > llms.txt

echo "Wrote catalog/modules.json and llms.txt for ${#modules[@]} modules."
