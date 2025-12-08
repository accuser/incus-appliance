#!/usr/bin/env bash
# sync-r2.sh - Smart sync to Cloudflare R2 with content-addressed uploads
# Only uploads new images (by fingerprint) to minimize R2 operations costs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Configuration
R2_BUCKET="${R2_BUCKET:-incus-appliance}"
REGISTRY_DIR="${REGISTRY_DIR:-${ROOT_DIR}/merged-registry}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}==>${NC} $*"; }
log_warn() { echo -e "${YELLOW}==>${NC} $*"; }
log_error() { echo -e "${RED}==>${NC} $*" >&2; }

# Check requirements
check_requirements() {
    if ! command -v rclone &> /dev/null; then
        log_error "rclone is not installed"
        exit 1
    fi

    if [[ -z "${R2_ACCOUNT_ID:-}" ]] || [[ -z "${R2_ACCESS_KEY_ID:-}" ]] || [[ -z "${R2_SECRET_ACCESS_KEY:-}" ]]; then
        log_error "R2 credentials not set. Required: R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY"
        exit 1
    fi
}

# Configure rclone for R2 (skip if already configured)
configure_rclone() {
    if [[ -f ~/.config/rclone/rclone.conf ]] && grep -q "^\[r2\]" ~/.config/rclone/rclone.conf 2>/dev/null; then
        log_info "rclone already configured, skipping"
        return
    fi

    log_info "Configuring rclone for Cloudflare R2..."

    # Create rclone config
    mkdir -p ~/.config/rclone

    cat > ~/.config/rclone/rclone.conf <<EOF
[r2]
type = s3
provider = Cloudflare
access_key_id = ${R2_ACCESS_KEY_ID}
secret_access_key = ${R2_SECRET_ACCESS_KEY}
endpoint = https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com
acl = private
EOF
    chmod 600 ~/.config/rclone/rclone.conf

    log_info "rclone configured"
}

# Check if an image already exists in R2 (by fingerprint)
image_exists() {
    local fingerprint="$1"
    # Use lsf to check if any files exist with this fingerprint prefix
    # This is a Class B operation (cheap)
    if rclone lsf "r2:${R2_BUCKET}/images/${fingerprint}." --max-depth 1 2>/dev/null | grep -q .; then
        return 0  # exists
    fi
    return 1  # does not exist
}

# Upload image files (only if fingerprint doesn't exist)
upload_images() {
    log_info "Uploading image files..."

    local uploaded=0
    local skipped=0

    # Find all image files
    if [[ -d "${REGISTRY_DIR}/images" ]]; then
        for file in "${REGISTRY_DIR}/images"/*; do
            if [[ -f "$file" ]]; then
                # Extract fingerprint from filename (format: FINGERPRINT.extension)
                filename=$(basename "$file")
                fingerprint="${filename%%.*}"

                if image_exists "$fingerprint"; then
                    log_info "  Skipping ${filename} (already exists)"
                    ((skipped++))
                else
                    log_info "  Uploading ${filename}..."
                    rclone copy "$file" "r2:${R2_BUCKET}/images/" \
                        --header-upload "Cache-Control: public, max-age=31536000, immutable" \
                        --s3-upload-concurrency 4
                    ((uploaded++))
                fi
            fi
        done
    fi

    log_info "Images: ${uploaded} uploaded, ${skipped} skipped (already exist)"
}

# Upload metadata files (always updated)
upload_metadata() {
    log_info "Uploading metadata files..."

    # Upload streams/v1/ files with short cache TTL
    if [[ -d "${REGISTRY_DIR}/streams/v1" ]]; then
        rclone sync "${REGISTRY_DIR}/streams/v1/" "r2:${R2_BUCKET}/streams/v1/" \
            --header-upload "Cache-Control: public, max-age=300" \
            --s3-upload-concurrency 4
        log_info "  Uploaded streams/v1/"
    fi

    # Upload index.html and other root files
    shopt -s nullglob
    for file in "${REGISTRY_DIR}"/*.html; do
        if [[ -f "$file" ]]; then
            rclone copy "$file" "r2:${R2_BUCKET}/" \
                --header-upload "Cache-Control: public, max-age=300" \
                --header-upload "Content-Type: text/html"
            log_info "  Uploaded $(basename "$file")"
        fi
    done
    shopt -u nullglob

    # Upload directory listing HTML files
    if [[ -d "${REGISTRY_DIR}/images" ]]; then
        find "${REGISTRY_DIR}/images" -name "index.html" | while read -r html_file; do
            rel_path="${html_file#"${REGISTRY_DIR}"/}"
            dir_path=$(dirname "$rel_path")
            rclone copy "$html_file" "r2:${R2_BUCKET}/${dir_path}/" \
                --header-upload "Cache-Control: public, max-age=300" \
                --header-upload "Content-Type: text/html"
        done
        log_info "  Uploaded directory listings"
    fi
}

# Verify upload
verify_upload() {
    log_info "Verifying upload..."

    # Check that index.json exists
    if rclone lsf "r2:${R2_BUCKET}/streams/v1/index.json" 2>/dev/null | grep -q .; then
        log_info "  ✓ index.json present"
    else
        log_error "  ✗ index.json missing!"
        return 1
    fi

    # Check that images.json exists
    if rclone lsf "r2:${R2_BUCKET}/streams/v1/images.json" 2>/dev/null | grep -q .; then
        log_info "  ✓ images.json present"
    else
        log_error "  ✗ images.json missing!"
        return 1
    fi

    log_info "Verification complete"
}

# Show R2 usage summary
show_summary() {
    log_info "R2 bucket summary:"
    rclone size "r2:${R2_BUCKET}" 2>/dev/null || log_warn "Could not get bucket size"
}

# Main
main() {
    log_info "Starting R2 sync..."

    check_requirements
    configure_rclone

    if [[ ! -d "$REGISTRY_DIR" ]]; then
        log_error "Registry directory not found: $REGISTRY_DIR"
        exit 1
    fi

    upload_images
    upload_metadata
    verify_upload
    show_summary

    log_info "R2 sync complete!"
}

main "$@"
