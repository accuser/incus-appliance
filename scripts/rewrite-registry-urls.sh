#!/usr/bin/env bash
set -euo pipefail

# Rewrite registry image URLs to point to GitHub Releases
# Usage: ./rewrite-registry-urls.sh <registry-dir> <github-repo> <release-tag>

REGISTRY_DIR="${1:?Usage: $0 <registry-dir> <github-repo> <release-tag>}"
GITHUB_REPO="${2:?Usage: $0 <registry-dir> <github-repo> <release-tag>}"
RELEASE_TAG="${3:-latest}"

IMAGES_JSON="${REGISTRY_DIR}/streams/v1/images.json"

if [[ ! -f "$IMAGES_JSON" ]]; then
  echo "Error: images.json not found at ${IMAGES_JSON}"
  exit 1
fi

echo "==> Rewriting URLs in ${IMAGES_JSON}"
echo "    Repository: ${GITHUB_REPO}"
echo "    Release tag: ${RELEASE_TAG}"

# Create a backup
cp "$IMAGES_JSON" "${IMAGES_JSON}.bak"

# Use jq to rewrite the paths to GitHub release URLs
# The images.json contains paths like "images/FINGERPRINT/incus.tar.xz"
# We need to change them to GitHub release download URLs

if command -v jq >/dev/null 2>&1; then
  # Use jq if available for proper JSON manipulation
  BASE_URL="https://github.com/${GITHUB_REPO}/releases/download/${RELEASE_TAG}"

  jq --arg base_url "$BASE_URL" '
    .products |= map_values(
      .versions |= map_values(
        .items |= map_values(
          if .path then
            .path = ($base_url + "/" + (.path | split("/") | last))
          else . end
        )
      )
    )
  ' "${IMAGES_JSON}.bak" > "$IMAGES_JSON"

  echo "==> URLs rewritten successfully"
else
  echo "Warning: jq not found, skipping URL rewriting"
  echo "Install jq with: sudo apt-get install jq"
  cp "${IMAGES_JSON}.bak" "$IMAGES_JSON"
fi

# Show a sample of what was changed
if command -v jq >/dev/null 2>&1; then
  echo ""
  echo "==> Sample URLs:"
  jq -r '.products[].versions[].items[].path // empty' "$IMAGES_JSON" | head -5
fi
