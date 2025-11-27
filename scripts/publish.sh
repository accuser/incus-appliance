#!/usr/bin/env bash
set -euo pipefail

# Publish registry to production server
# Usage: ./publish.sh [destination]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REGISTRY_DIR="${PROJECT_ROOT}/registry"

# Configuration (override via environment variables)
PUBLISH_DEST="${1:-${PUBLISH_DEST:-}}"
PUBLISH_METHOD="${PUBLISH_METHOD:-rsync}"  # rsync, s3, or custom
RSYNC_OPTS="${RSYNC_OPTS:--avz --delete --progress}"

if [[ -z "$PUBLISH_DEST" ]]; then
  echo "Error: No destination specified"
  echo ""
  echo "Usage: $0 <destination>"
  echo ""
  echo "Examples:"
  echo "  $0 user@server:/var/www/appliances"
  echo "  PUBLISH_METHOD=s3 $0 s3://my-bucket/appliances"
  echo ""
  echo "Or set PUBLISH_DEST environment variable:"
  echo "  export PUBLISH_DEST=user@server:/var/www/appliances"
  echo "  $0"
  exit 1
fi

if [[ ! -d "$REGISTRY_DIR" ]]; then
  echo "Error: Registry directory not found at ${REGISTRY_DIR}"
  echo "Run 'make build' first to create the registry."
  exit 1
fi

echo "==> Publishing registry to: ${PUBLISH_DEST}"
echo "    Method: ${PUBLISH_METHOD}"
echo ""

case "$PUBLISH_METHOD" in
  rsync)
    echo "==> Using rsync to publish..."
    # shellcheck disable=SC2086
    rsync $RSYNC_OPTS "${REGISTRY_DIR}/" "${PUBLISH_DEST}/"
    ;;

  s3)
    echo "==> Using AWS S3 to publish..."
    if ! command -v aws >/dev/null 2>&1; then
      echo "Error: aws cli not found. Install with: pip install awscli"
      exit 1
    fi
    aws s3 sync "${REGISTRY_DIR}/" "${PUBLISH_DEST}/" --delete
    ;;

  custom)
    # For custom publish scripts
    if [[ -x "${PROJECT_ROOT}/scripts/publish-custom.sh" ]]; then
      echo "==> Using custom publish script..."
      "${PROJECT_ROOT}/scripts/publish-custom.sh" "$REGISTRY_DIR" "$PUBLISH_DEST"
    else
      echo "Error: Custom publish method specified but scripts/publish-custom.sh not found or not executable"
      exit 1
    fi
    ;;

  *)
    echo "Error: Unknown publish method: ${PUBLISH_METHOD}"
    echo "Supported methods: rsync, s3, custom"
    exit 1
    ;;
esac

echo ""
echo "==> Registry published successfully!"
echo ""
echo "Users can now add the remote:"
echo "  incus remote add appliance ${PUBLISH_DEST%%:*} --protocol simplestreams"
