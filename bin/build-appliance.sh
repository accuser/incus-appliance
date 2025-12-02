#!/usr/bin/env bash
set -euo pipefail

# Build a single appliance image using Incus
# Usage: ./build-appliance-incus.sh <appliance-name> [architecture]
#
# This script:
# 1. Launches a container from images:debian/12/cloud
# 2. Waits for cloud-init to complete
# 3. Copies files from files/ directory
# 4. Stops the container
# 5. Publishes it as an image
# 6. Exports to incus.tar.xz and rootfs.squashfs
# 7. Adds to SimpleStreams registry

APPLIANCE="${1:?Usage: $0 <appliance-name> [arch]}"
ARCH="${2:-$(uname -m)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APPLIANCE_DIR="${PROJECT_ROOT}/appliances/${APPLIANCE}"
REGISTRY_DIR="${PROJECT_ROOT}/registry"

# Normalize architecture names (must happen before BUILD_DIR and BUILD_CONTAINER)
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
esac

BUILD_DIR="${PROJECT_ROOT}/.build/${APPLIANCE}/${ARCH}"

# Container name for build (unique to avoid conflicts in parallel builds)
BUILD_CONTAINER="build-${APPLIANCE}-${ARCH}-$$"

# Extract version from appliance.yaml (default to 0.0.0 if not found)
VERSION="0.0.0"
if [[ -f "${APPLIANCE_DIR}/appliance.yaml" ]]; then
  EXTRACTED_VERSION=$(grep '^\s*version:' "${APPLIANCE_DIR}/appliance.yaml" | awk '{print $2}' | tr -d '"' | tr -d "'" || true)
  if [[ -n "$EXTRACTED_VERSION" ]]; then
    VERSION="$EXTRACTED_VERSION"
  fi
fi

# Parse semantic version components
VERSION_MAJOR="${VERSION%%.*}"
VERSION_MINOR_PATCH="${VERSION#*.}"
VERSION_MINOR="${VERSION_MINOR_PATCH%%.*}"

# Validate appliance exists
if [[ ! -d "$APPLIANCE_DIR" ]]; then
  echo "Error: Appliance '${APPLIANCE}' not found in ${PROJECT_ROOT}/appliances/"
  exit 1
fi

if [[ ! -f "${APPLIANCE_DIR}/config.yaml" ]]; then
  echo "Error: Missing config.yaml in ${APPLIANCE_DIR}"
  exit 1
fi

echo "==> Building appliance: ${APPLIANCE} v${VERSION} (${ARCH})"

# Create build directory
mkdir -p "$BUILD_DIR"

# Determine if we need sudo for incus commands
# If user can access incus socket directly, no sudo needed
SUDO=""
if ! incus info >/dev/null 2>&1; then
  if sudo incus info >/dev/null 2>&1; then
    SUDO="sudo"
    echo "==> Using sudo for incus commands"
  else
    echo "Error: Cannot access Incus. Ensure Incus is running and user has permissions."
    exit 1
  fi
fi

# Cleanup function
cleanup() {
  echo "==> Cleaning up build container..."
  $SUDO incus delete -f "$BUILD_CONTAINER" 2>/dev/null || true
}
trap cleanup EXIT

# Create container from Debian 12 cloud image (don't start yet)
echo "==> Creating build container from images:debian/12/cloud..."
$SUDO incus init "images:debian/12/cloud/${ARCH}" "$BUILD_CONTAINER"

# Apply cloud-init configuration BEFORE first boot
echo "==> Applying cloud-init configuration..."
# Read the config.yaml and extract cloud-init.user-data
CLOUD_INIT_DATA=$(yq -r '.config."cloud-init.user-data" // ""' "${APPLIANCE_DIR}/config.yaml")
if [[ -n "$CLOUD_INIT_DATA" ]]; then
  # Set cloud-init user-data on the container
  $SUDO incus config set "$BUILD_CONTAINER" cloud-init.user-data "$CLOUD_INIT_DATA"
fi

# Check for network config
NETWORK_CONFIG=$(yq -r '.config."cloud-init.network-config" // ""' "${APPLIANCE_DIR}/config.yaml")
if [[ -n "$NETWORK_CONFIG" ]]; then
  $SUDO incus config set "$BUILD_CONTAINER" cloud-init.network-config "$NETWORK_CONFIG"
fi

# Start the container (cloud-init will run on first boot with our config)
echo "==> Starting container..."
$SUDO incus start "$BUILD_CONTAINER"

# Wait for cloud-init to complete
echo "==> Waiting for cloud-init to complete..."
MAX_WAIT=300
WAIT_INTERVAL=5
WAITED=0
while [[ $WAITED -lt $MAX_WAIT ]]; do
  # Check if cloud-init has finished
  if $SUDO incus exec "$BUILD_CONTAINER" -- test -f /var/lib/cloud/instance/boot-finished 2>/dev/null; then
    echo "==> cloud-init completed"
    break
  fi
  echo "    Waiting for cloud-init... (${WAITED}s/${MAX_WAIT}s)"
  sleep $WAIT_INTERVAL
  WAITED=$((WAITED + WAIT_INTERVAL))
done

if [[ $WAITED -ge $MAX_WAIT ]]; then
  echo "Error: cloud-init did not complete within ${MAX_WAIT} seconds"
  echo "==> cloud-init status:"
  $SUDO incus exec "$BUILD_CONTAINER" -- cloud-init status --long 2>/dev/null || true
  echo "==> cloud-init logs:"
  $SUDO incus exec "$BUILD_CONTAINER" -- tail -50 /var/log/cloud-init-output.log 2>/dev/null || true
  exit 1
fi

# Show cloud-init result
echo "==> cloud-init status:"
$SUDO incus exec "$BUILD_CONTAINER" -- cloud-init status --long 2>/dev/null || true

# Copy files from files/ directory if it exists
if [[ -d "${APPLIANCE_DIR}/files" ]]; then
  echo "==> Copying files from files/ directory..."
  # Find all files and push them preserving directory structure
  cd "${APPLIANCE_DIR}/files"
  find . -type f | while read -r file; do
    # Remove leading ./
    rel_path="${file#./}"
    dest_path="/${rel_path}"
    dest_dir=$(dirname "$dest_path")

    # Ensure destination directory exists
    $SUDO incus exec "$BUILD_CONTAINER" -- mkdir -p "$dest_dir"

    # Push the file
    echo "    Copying: ${rel_path} -> ${dest_path}"
    $SUDO incus file push "$file" "${BUILD_CONTAINER}${dest_path}"
  done
  cd "$PROJECT_ROOT"
fi

# Run post-files commands if defined
POST_FILES_CMD=$(yq -r '.post_files // ""' "${APPLIANCE_DIR}/config.yaml")
if [[ -n "$POST_FILES_CMD" ]]; then
  echo "==> Running post-files commands..."
  $SUDO incus exec "$BUILD_CONTAINER" -- bash -c "$POST_FILES_CMD"
fi

# Clean up the container for image creation
echo "==> Cleaning up container for image creation..."
$SUDO incus exec "$BUILD_CONTAINER" -- bash -c '
  # Clean cloud-init state so it runs again on first boot
  cloud-init clean --logs 2>/dev/null || true

  # Clean package cache
  apt-get clean 2>/dev/null || true
  rm -rf /var/lib/apt/lists/* 2>/dev/null || true

  # Clean temporary files
  rm -rf /tmp/* /var/tmp/* 2>/dev/null || true

  # Clear log files from build process
  find /var/log -type f -name "*.log" -delete 2>/dev/null || true
  find /var/log -type f -name "*.gz" -delete 2>/dev/null || true
  : > /var/log/wtmp 2>/dev/null || true
  : > /var/log/btmp 2>/dev/null || true
  : > /var/log/lastlog 2>/dev/null || true

  # Clear shell history
  rm -f /root/.bash_history 2>/dev/null || true
  rm -f /home/*/.bash_history 2>/dev/null || true

  # Remove SSH host keys (will be regenerated on first boot)
  rm -f /etc/ssh/ssh_host_* 2>/dev/null || true

  # Clear machine-id (will be regenerated on first boot)
  truncate -s 0 /etc/machine-id 2>/dev/null || true
  rm -f /var/lib/dbus/machine-id 2>/dev/null || true

  # Clear other caches
  rm -rf /var/cache/apt/* 2>/dev/null || true
  rm -rf /var/cache/debconf/* 2>/dev/null || true
'

# Stop the container
echo "==> Stopping container..."
$SUDO incus stop "$BUILD_CONTAINER"

# Publish as image
echo "==> Publishing container as image..."
IMAGE_ALIAS="appliance-${APPLIANCE}-${ARCH}-build"
# Delete any existing image with this alias to avoid conflicts
$SUDO incus image delete "$IMAGE_ALIAS" 2>/dev/null || true
$SUDO incus publish "$BUILD_CONTAINER" --alias "$IMAGE_ALIAS"

# Export the image as a unified tarball
echo "==> Exporting image..."
cd "$BUILD_DIR"
$SUDO incus image export "$IMAGE_ALIAS" .

# Find the exported file (could be .tar.gz or .tar.xz)
EXPORTED_FILE=$(find . -maxdepth 1 -name "*.tar.*" -type f | head -1)
EXPORTED_FILE="${EXPORTED_FILE#./}"  # Remove leading ./
if [[ -z "$EXPORTED_FILE" ]]; then
  echo "Error: No exported image file found"
  ls -la
  exit 1
fi
echo "    Exported: ${EXPORTED_FILE}"

# Convert unified tarball to split format for incus-simplestreams
echo "==> Converting to split image format..."
WORK_DIR="${BUILD_DIR}/work"
mkdir -p "$WORK_DIR"

# Extract the unified tarball
tar -xf "$EXPORTED_FILE" -C "$WORK_DIR"

# Create metadata tarball (contains metadata.yaml and templates/)
echo "    Creating metadata tarball..."
cd "$WORK_DIR"
tar -cJf "${BUILD_DIR}/incus.tar.xz" metadata.yaml templates/ 2>/dev/null || \
  tar -cJf "${BUILD_DIR}/incus.tar.xz" metadata.yaml

# Create squashfs from rootfs
echo "    Creating rootfs squashfs..."
$SUDO mksquashfs rootfs "${BUILD_DIR}/rootfs.squashfs" -noappend -comp xz -quiet

# Clean up work directory
cd "$BUILD_DIR"
$SUDO rm -rf "$WORK_DIR"
rm -f "$EXPORTED_FILE"

# Verify outputs
if [[ ! -f "incus.tar.xz" ]] || [[ ! -f "rootfs.squashfs" ]]; then
  echo "Error: Failed to create split image files"
  ls -la
  exit 1
fi
echo "    Created: incus.tar.xz and rootfs.squashfs"

# Clean up the temporary image
$SUDO incus image delete "$IMAGE_ALIAS" 2>/dev/null || true

# Add to SimpleStreams registry
echo "==> Adding to SimpleStreams registry..."
mkdir -p "$REGISTRY_DIR"

# Use incus-simplestreams to add the image
# Aliases follow semantic versioning: name, name:version, name:major.minor, name:major, name:latest
# Note: incus-simplestreams automatically adds /${ARCH} suffix to aliases
cd "$REGISTRY_DIR"
$SUDO incus-simplestreams add \
  "$BUILD_DIR/incus.tar.xz" \
  "$BUILD_DIR/rootfs.squashfs" \
  --alias "${APPLIANCE}" \
  --alias "${APPLIANCE}:${VERSION}" \
  --alias "${APPLIANCE}:${VERSION_MAJOR}.${VERSION_MINOR}" \
  --alias "${APPLIANCE}:${VERSION_MAJOR}" \
  --alias "${APPLIANCE}:latest"

echo "==> Successfully built: ${APPLIANCE} v${VERSION} (${ARCH})"
echo "    Registry: ${REGISTRY_DIR}"
echo "    Aliases:"
echo "      - ${APPLIANCE}"
echo "      - ${APPLIANCE}:${VERSION}"
echo "      - ${APPLIANCE}:${VERSION_MAJOR}.${VERSION_MINOR}"
echo "      - ${APPLIANCE}:${VERSION_MAJOR}"
echo "      - ${APPLIANCE}:latest"
echo "    (Architecture suffix /${ARCH} added automatically)"
