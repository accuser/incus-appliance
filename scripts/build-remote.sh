#!/usr/bin/env bash
set -euo pipefail

# Build an appliance using the build VM
# Usage: ./build-remote.sh <appliance-name> [architecture] [vm-name]

APPLIANCE="${1:?Usage: $0 <appliance-name> [arch] [vm-name]}"
ARCH="${2:-$(uname -m)}"
VM_NAME="${3:-appliance-builder}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Normalize architecture names
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
esac

echo "==> Building ${APPLIANCE} (${ARCH}) using VM: ${VM_NAME}"

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

# Execute build inside the VM
# The VM has bin/ and appliances/ from sparse checkout
incus exec "$VM_NAME" -- bash -c "cd incus-appliance && sudo ./bin/build-appliance.sh '$APPLIANCE' '$ARCH'"

echo ""
echo "==> Build complete!"
echo "    Built: ${APPLIANCE} (${ARCH})"
echo "    Registry: ${PROJECT_ROOT}/registry/"
echo ""
