#!/usr/bin/env bash
set -euo pipefail

# Build a single appliance image
# Usage: ./build-appliance.sh <appliance-name> [architecture]

APPLIANCE="${1:?Usage: $0 <appliance-name> [arch]}"
ARCH="${2:-$(uname -m)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APPLIANCE_DIR="${PROJECT_ROOT}/appliances/${APPLIANCE}"
BUILD_DIR="${PROJECT_ROOT}/.build/${APPLIANCE}/${ARCH}"
REGISTRY_DIR="${PROJECT_ROOT}/registry"

# Normalize architecture names
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
esac

# Determine architecture mapping for the source downloader
# Some distributions (like Alpine) use different arch names
SOURCE_ARCH="$ARCH"
if [[ -f "${APPLIANCE_DIR}/image.yaml" ]]; then
  DISTRO=$(grep '^\s*distribution:' "${APPLIANCE_DIR}/image.yaml" | awk '{print $2}' | tr -d '"')
  if [[ "$DISTRO" == "alpine" ]]; then
    case "$ARCH" in
      amd64) SOURCE_ARCH="x86_64" ;;
      arm64) SOURCE_ARCH="aarch64" ;;
    esac
  fi
fi

# Validate appliance exists
if [[ ! -d "$APPLIANCE_DIR" ]]; then
  echo "Error: Appliance '${APPLIANCE}' not found in ${PROJECT_ROOT}/appliances/"
  exit 1
fi

if [[ ! -f "${APPLIANCE_DIR}/image.yaml" ]]; then
  echo "Error: Missing image.yaml in ${APPLIANCE_DIR}"
  exit 1
fi

echo "==> Building appliance: ${APPLIANCE} (${ARCH})"

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Copy template and files
cp "${APPLIANCE_DIR}/image.yaml" ./
if [[ -d "${APPLIANCE_DIR}/files" ]]; then
  cp -r "${APPLIANCE_DIR}/files" ./
fi

# Fix Alpine URLs for the target architecture
if [[ "$DISTRO" == "alpine" ]] && grep -q "rootfs-http" image.yaml; then
  # Replace x86_64 with the correct SOURCE_ARCH in the URL
  sed -i "s/x86_64/${SOURCE_ARCH}/g" image.yaml
  # Also replace aarch64 in case we're going the other direction
  if [[ "$SOURCE_ARCH" == "x86_64" ]]; then
    sed -i "s/aarch64/${SOURCE_ARCH}/g" image.yaml
  fi
fi

# Build with distrobuilder
echo "==> Running distrobuilder..."
sudo distrobuilder build-incus image.yaml \
  --type=split \
  --disable-overlay \
  -o image.architecture="${ARCH}" \
  -o image.architecture_mapped="${SOURCE_ARCH}" \
  --cache-dir="${PROJECT_ROOT}/.cache/distrobuilder"

# Verify outputs
if [[ ! -f "incus.tar.xz" ]] || [[ ! -f "rootfs.squashfs" ]]; then
  echo "Error: distrobuilder did not produce expected outputs"
  ls -la
  exit 1
fi

# Add to simplestreams registry
echo "==> Adding to SimpleStreams registry..."
mkdir -p "$REGISTRY_DIR"

# Use incus-simplestreams to add the image
# The command must be run from the registry directory
# The alias format follows: name/arch or just name
cd "$REGISTRY_DIR"
sudo incus-simplestreams add \
  "$BUILD_DIR/incus.tar.xz" \
  "$BUILD_DIR/rootfs.squashfs" \
  --alias "${APPLIANCE}" \
  --alias "${APPLIANCE}/${ARCH}"

echo "==> Successfully built: ${APPLIANCE} (${ARCH})"
echo "    Registry: ${REGISTRY_DIR}"
echo "    Aliases: ${APPLIANCE}, ${APPLIANCE}/${ARCH}"
