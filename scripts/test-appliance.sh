#!/usr/bin/env bash
set -euo pipefail

# Test an appliance by launching it and running health checks
# Usage: ./test-appliance.sh <appliance-name> [remote]

APPLIANCE="${1:?Usage: $0 <appliance-name> [remote]}"
REMOTE="${2:-appliance-test}"
INSTANCE_NAME="test-${APPLIANCE}-$$"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cleanup() {
  echo "==> Cleaning up..."
  incus delete -f "$INSTANCE_NAME" 2>/dev/null || true
}
trap cleanup EXIT

echo "==> Testing appliance: ${APPLIANCE}"

# Check if incus is installed
if ! command -v incus >/dev/null 2>&1; then
  echo "Error: incus command not found"
  exit 1
fi

# Check remote exists
if ! incus remote list | grep -q "^| ${REMOTE} "; then
  echo "Error: Remote '${REMOTE}' not configured"
  echo "Run: incus remote add ${REMOTE} https://localhost:8443 --protocol simplestreams --accept-certificate"
  exit 1
fi

# Check if image exists in remote
if ! incus image list "${REMOTE}:" 2>/dev/null | grep -q "${APPLIANCE}"; then
  echo "Error: Image '${APPLIANCE}' not found in remote '${REMOTE}'"
  echo "Available images:"
  incus image list "${REMOTE}:"
  exit 1
fi

# Launch instance
echo "==> Launching ${REMOTE}:${APPLIANCE} as ${INSTANCE_NAME}..."
if ! incus launch "${REMOTE}:${APPLIANCE}" "$INSTANCE_NAME"; then
  echo "Error: Failed to launch instance"
  exit 1
fi

# Wait for instance to be ready
echo "==> Waiting for instance to start..."
for i in {1..30}; do
  STATE=$(incus info "$INSTANCE_NAME" | grep '^Status:' | awk '{print $2}')
  if [[ "$STATE" == "RUNNING" ]]; then
    break
  fi
  sleep 1
done

# Check instance is running
STATE=$(incus info "$INSTANCE_NAME" | grep '^Status:' | awk '{print $2}')
if [[ "$STATE" != "RUNNING" ]]; then
  echo "Error: Instance not running (state: ${STATE})"
  incus info "$INSTANCE_NAME"
  exit 1
fi

echo "    Instance is running"

# Wait for cloud-init if applicable
if incus exec "$INSTANCE_NAME" -- test -f /usr/bin/cloud-init 2>/dev/null; then
  echo "==> Waiting for cloud-init..."
  timeout 60 incus exec "$INSTANCE_NAME" -- cloud-init status --wait || echo "    (cloud-init not blocking)"
fi

# Give services a moment to start
sleep 3

# Run health check if defined
APPLIANCE_DIR="${PROJECT_ROOT}/appliances/${APPLIANCE}"
if [[ -f "${APPLIANCE_DIR}/appliance.yaml" ]]; then
  HEALTHCHECK=$(grep -A5 '^healthcheck:' "${APPLIANCE_DIR}/appliance.yaml" 2>/dev/null | grep 'command:' | cut -d'"' -f2 || true)
  if [[ -n "$HEALTHCHECK" ]]; then
    echo "==> Running health check: ${HEALTHCHECK}"
    if incus exec "$INSTANCE_NAME" -- sh -c "$HEALTHCHECK"; then
      echo "    ✓ Health check passed"
    else
      echo "    ✗ Health check failed"
      echo "==> Instance logs:"
      incus exec "$INSTANCE_NAME" -- dmesg | tail -20
      exit 1
    fi
  fi
fi

# Basic connectivity test
echo "==> Testing basic functionality..."
incus exec "$INSTANCE_NAME" -- uname -a
incus exec "$INSTANCE_NAME" -- cat /etc/os-release | head -5

# Show instance info
echo ""
echo "==> Instance information:"
echo "    Name: ${INSTANCE_NAME}"
echo "    State: ${STATE}"
echo "    Image: ${REMOTE}:${APPLIANCE}"

# Check if MOTD exists and display it
if incus exec "$INSTANCE_NAME" -- test -f /etc/motd 2>/dev/null; then
  echo ""
  echo "==> MOTD:"
  incus exec "$INSTANCE_NAME" -- cat /etc/motd
fi

echo ""
echo "==> All tests passed for: ${APPLIANCE}"
echo ""
echo "The instance will be automatically cleaned up."
echo "To keep it running, press Ctrl+C before cleanup."
sleep 2
