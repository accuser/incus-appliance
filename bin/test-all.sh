#!/usr/bin/env bash
set -euo pipefail

# Run integration tests for all appliances

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REMOTE="${REMOTE:-appliance-test}"

echo "==> Running integration tests for all appliances"
echo "    Remote: ${REMOTE}"
echo ""

# Check remote exists
if ! incus remote list | grep -q "^| ${REMOTE} "; then
  echo "Error: Remote '${REMOTE}' not configured"
  echo "Run: incus remote add ${REMOTE} https://localhost:8443 --protocol simplestreams --accept-certificate"
  exit 1
fi

# Get list of appliances
appliances=()
for appliance_dir in "${PROJECT_ROOT}/appliances"/*; do
  [[ ! -d "$appliance_dir" ]] && continue
  [[ "$(basename "$appliance_dir")" == "_base" ]] && continue
  appliances+=("$(basename "$appliance_dir")")
done

if [[ ${#appliances[@]} -eq 0 ]]; then
  echo "No appliances found to test"
  exit 1
fi

echo "Found ${#appliances[@]} appliance(s) to test"
echo ""

failed=()
passed=()

for appliance in "${appliances[@]}"; do
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Testing: ${appliance}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if "${SCRIPT_DIR}/test-appliance.sh" "$appliance" "$REMOTE"; then
    passed+=("$appliance")
    echo "✓ ${appliance} passed"
  else
    failed+=("$appliance")
    echo "✗ ${appliance} failed"
  fi

  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Passed: ${#passed[@]}"
echo "Failed: ${#failed[@]}"
echo ""

if [[ ${#passed[@]} -gt 0 ]]; then
  echo "✓ Passed appliances:"
  for app in "${passed[@]}"; do
    echo "  - ${app}"
  done
  echo ""
fi

if [[ ${#failed[@]} -gt 0 ]]; then
  echo "✗ Failed appliances:"
  for app in "${failed[@]}"; do
    echo "  - ${app}"
  done
  echo ""
  exit 1
fi

echo "All tests passed!"
exit 0
