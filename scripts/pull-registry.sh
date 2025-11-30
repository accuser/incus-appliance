#!/usr/bin/env bash
set -euo pipefail

# Pull the registry from the build VM to the host
# Usage: ./pull-registry.sh [vm-name]

VM_NAME="${1:-appliance-builder}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REGISTRY_DIR="${PROJECT_ROOT}/registry"

echo "==> Pulling registry from VM: ${VM_NAME}"

# Check if VM exists and is running
if ! incus list --format csv --columns ns | grep -q "^${VM_NAME},"; then
  echo "Error: VM '${VM_NAME}' does not exist"
  echo ""
  echo "To create the build VM, run:"
  echo "  ./scripts/setup-build-vm.sh"
  exit 1
fi

# Check if registry exists in VM
if ! incus exec "$VM_NAME" -- test -d /root/incus-appliance/registry; then
  echo "Error: No registry found in VM"
  echo "Build an appliance first with:"
  echo "  ./scripts/build-remote.sh <appliance-name>"
  exit 1
fi

# Create local registry directory if it doesn't exist
mkdir -p "$REGISTRY_DIR"

# Pull registry from VM using incus file pull recursively
echo "==> Copying registry files from VM to host..."

# Use tar to preserve permissions and efficiently transfer
incus exec "$VM_NAME" -- tar -C /root/incus-appliance -czf - registry | tar -C "$PROJECT_ROOT" -xzf -

echo ""
echo "==> Registry pulled successfully!"
echo "    Location: ${REGISTRY_DIR}"
echo ""
echo "To list images in the registry:"
echo "  make registry-list"
echo ""
echo "To publish the registry:"
echo "  ./scripts/publish.sh user@server:/var/www/appliances"
echo ""
