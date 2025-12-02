#!/usr/bin/env bash
set -euo pipefail

# Build all appliances
# Usage: ./build-all.sh [architecture]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ARCH="${1:-$(uname -m)}"

echo "==> Building all appliances for ${ARCH}"
echo ""

# Find all appliances
appliances=()
for appliance_dir in "${PROJECT_ROOT}/appliances"/*; do
  [[ ! -d "$appliance_dir" ]] && continue
  [[ "$(basename "$appliance_dir")" == "_base" ]] && continue

  appliance=$(basename "$appliance_dir")
  if [[ -f "${appliance_dir}/config.yaml" ]]; then
    appliances+=("$appliance")
  fi
done

if [[ ${#appliances[@]} -eq 0 ]]; then
  echo "No appliances found to build"
  exit 1
fi

echo "Found ${#appliances[@]} appliance(s) to build"
echo ""

failed=()
succeeded=()

for appliance in "${appliances[@]}"; do
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Building: ${appliance}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if "${SCRIPT_DIR}/build-appliance-incus.sh" "$appliance" "$ARCH"; then
    succeeded+=("$appliance")
  else
    failed+=("$appliance")
    echo "✗ Failed to build ${appliance}"
  fi

  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Build Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Succeeded: ${#succeeded[@]}"
echo "Failed: ${#failed[@]}"
echo ""

if [[ ${#succeeded[@]} -gt 0 ]]; then
  echo "✓ Successfully built:"
  for app in "${succeeded[@]}"; do
    echo "  - ${app}"
  done
  echo ""
fi

if [[ ${#failed[@]} -gt 0 ]]; then
  echo "✗ Failed to build:"
  for app in "${failed[@]}"; do
    echo "  - ${app}"
  done
  echo ""
  exit 1
fi

echo "All builds completed successfully!"
exit 0
