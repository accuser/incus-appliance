#!/usr/bin/env bash
set -euo pipefail

# Build all appliances using the build VM
# Usage: ./build-all-remote.sh [architecture] [vm-name]

ARCH="${1:-$(uname -m)}"
VM_NAME="${2:-appliance-builder}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Normalize architecture names
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
esac

echo "==> Building all appliances (${ARCH}) using VM: ${VM_NAME}"

# Check if VM exists and is running
if ! incus list --format csv --columns ns | grep -q "^${VM_NAME},RUNNING$"; then
  echo "Error: VM '${VM_NAME}' is not running"
  echo ""
  echo "To create the build VM, run:"
  echo "  ./scripts/setup-build-vm.sh"
  echo ""
  echo "To start an existing VM, run:"
  echo "  incus start ${VM_NAME}"
  exit 1
fi

# Find all appliances (directories with image.yaml)
APPLIANCES=()
for dir in "${PROJECT_ROOT}/appliances"/*; do
  if [[ -d "$dir" ]] && [[ -f "$dir/image.yaml" ]]; then
    APPLIANCE=$(basename "$dir")
    # Skip _base directory
    if [[ "$APPLIANCE" != "_base" ]]; then
      APPLIANCES+=("$APPLIANCE")
    fi
  fi
done

if [[ ${#APPLIANCES[@]} -eq 0 ]]; then
  echo "Error: No appliances found in ${PROJECT_ROOT}/appliances/"
  exit 1
fi

echo "Found ${#APPLIANCES[@]} appliances to build:"
printf '  - %s\n' "${APPLIANCES[@]}"
echo ""

# Build each appliance
FAILED=()
for appliance in "${APPLIANCES[@]}"; do
  echo "==> Building: ${appliance}"
  if "${SCRIPT_DIR}/build-remote.sh" "$appliance" "$ARCH" "$VM_NAME"; then
    echo "✓ ${appliance} built successfully"
  else
    echo "✗ ${appliance} failed to build"
    FAILED+=("$appliance")
  fi
  echo ""
done

# Summary
echo "==> Build Summary"
echo "    Total: ${#APPLIANCES[@]}"
echo "    Succeeded: $((${#APPLIANCES[@]} - ${#FAILED[@]}))"
echo "    Failed: ${#FAILED[@]}"

if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo ""
  echo "Failed appliances:"
  printf '  - %s\n' "${FAILED[@]}"
  exit 1
fi

echo ""
echo "==> All appliances built successfully!"
