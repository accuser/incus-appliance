#!/usr/bin/env bash
set -euo pipefail

# Check if the base image has been updated
# Usage: ./check-base-image.sh [--update]
#
# This script compares the current base image fingerprint from the remote
# images server against a stored baseline. If they differ, the base image
# has been updated and appliances should be rebuilt.
#
# Options:
#   --update    Update the stored fingerprint after checking
#
# Exit codes:
#   0 - Base image has changed (or no baseline exists)
#   1 - Base image unchanged
#   2 - Error occurred

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FINGERPRINT_FILE="${PROJECT_ROOT}/.base-image-fingerprint"

# Base image configuration
BASE_IMAGE="images:debian/12/cloud"
DEFAULT_ARCH="amd64"

# Parse arguments
UPDATE_FINGERPRINT=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --update)
      UPDATE_FINGERPRINT=true
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--update]" >&2
      exit 2
      ;;
  esac
done

# Determine if we need sudo for incus commands
SUDO=""
if ! incus info >/dev/null 2>&1; then
  if sudo incus info >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "Error: Cannot access Incus. Ensure Incus is running and user has permissions." >&2
    exit 2
  fi
fi

echo "==> Checking base image: ${BASE_IMAGE}"

# Get the current remote image fingerprint
# We query the remote directly without downloading
REMOTE_FINGERPRINT=""
if ! REMOTE_FINGERPRINT=$($SUDO incus image info "${BASE_IMAGE}/${DEFAULT_ARCH}" 2>/dev/null | grep "^Fingerprint:" | awk '{print $2}'); then
  echo "Error: Could not fetch remote image info" >&2
  exit 2
fi

if [[ -z "$REMOTE_FINGERPRINT" ]]; then
  echo "Error: Could not determine remote image fingerprint" >&2
  exit 2
fi

echo "    Remote fingerprint: ${REMOTE_FINGERPRINT:0:12}..."

# Check if we have a stored fingerprint
if [[ -f "$FINGERPRINT_FILE" ]]; then
  STORED_FINGERPRINT=$(cat "$FINGERPRINT_FILE")
  echo "    Stored fingerprint: ${STORED_FINGERPRINT:0:12}..."

  if [[ "$REMOTE_FINGERPRINT" == "$STORED_FINGERPRINT" ]]; then
    echo "==> Base image unchanged"
    exit 1  # Exit 1 = no change
  else
    echo "==> Base image has been updated!"
    if [[ "$UPDATE_FINGERPRINT" == "true" ]]; then
      echo "$REMOTE_FINGERPRINT" > "$FINGERPRINT_FILE"
      echo "    Updated stored fingerprint"
    fi
    exit 0  # Exit 0 = changed
  fi
else
  echo "    No stored fingerprint found (first run)"
  if [[ "$UPDATE_FINGERPRINT" == "true" ]]; then
    echo "$REMOTE_FINGERPRINT" > "$FINGERPRINT_FILE"
    echo "    Saved initial fingerprint"
  fi
  echo "==> Base image check initialized"
  exit 0  # Exit 0 = should build (no baseline)
fi
