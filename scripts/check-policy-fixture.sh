#!/usr/bin/env bash
# Plan the insecure fixture and require the policies to deny it with every expected rule ID.
# Needs an AWS endpoint for planning (LocalStack in CI): AWS_ENDPOINT_URL and dummy credentials.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
fixture="$root/policies/fixtures/aws-insecure"
tf="${TF:-terraform}"

cd "$fixture"
echo "== Planning the insecure fixture"
"$tf" init -backend=false -input=false >/dev/null
"$tf" plan -input=false -out tfplan >/dev/null
"$tf" show -json tfplan > plan.json

echo "== Running the policies (they must deny)"
set +e
output=$(conftest test plan.json -p "$root/policies" --data "$root/policies/data" --all-namespaces --no-color 2>&1)
status=$?
set -e
echo "$output" | grep -E '^FAIL' || true

if [ "$status" -eq 0 ]; then
  echo "::error::The policies allowed an insecure plan."
  exit 1
fi

missing=0
while read -r rule; do
  [ -z "$rule" ] && continue
  if ! grep -q "\[$rule\]" <<<"$output"; then
    echo "::error::Expected a [$rule] denial, got none."
    missing=1
  fi
done < expected-denials.txt

rm -rf .terraform .terraform.lock.hcl tfplan plan.json
[ "$missing" -eq 0 ] && echo "== Every expected rule denied the fixture."
exit "$missing"
