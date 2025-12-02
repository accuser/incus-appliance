#!/usr/bin/env bash
set -euo pipefail

# Validate all appliance templates
# Checks for required files, YAML syntax, and cloud-init configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APPLIANCES_DIR="${PROJECT_ROOT}/appliances"

errors=0
warnings=0

# Check if validation tools are available
YQ_AVAILABLE=false
if command -v yq >/dev/null 2>&1; then
  YQ_AVAILABLE=true
  echo "==> yq found - cloud-init validation enabled"
else
  echo "==> yq not found - install yq for full validation"
fi

YAMLLINT_AVAILABLE=false
if command -v yamllint >/dev/null 2>&1; then
  YAMLLINT_AVAILABLE=true
  echo "==> yamllint found - YAML syntax validation enabled"
fi
echo ""

# Validate root appliances.yaml if it exists
if [[ -f "${PROJECT_ROOT}/appliances.yaml" ]]; then
  echo "==> Validating appliances.yaml manifest..."

  # YAML syntax check
  if [[ "$YAMLLINT_AVAILABLE" == "true" ]]; then
    if yamllint -d relaxed "${PROJECT_ROOT}/appliances.yaml" >/dev/null 2>&1; then
      echo "  ✓ Valid YAML syntax"
    else
      echo "  ✗ Invalid YAML syntax"
      yamllint -d relaxed "${PROJECT_ROOT}/appliances.yaml" 2>&1 | head -10
      ((errors++))
    fi
  fi
  echo ""
fi

echo "==> Validating appliance templates..."
echo ""

# Find all appliances (exclude _base)
for appliance_dir in "${APPLIANCES_DIR}"/*; do
  [[ ! -d "$appliance_dir" ]] && continue
  [[ "$(basename "$appliance_dir")" == "_base" ]] && continue

  appliance_name=$(basename "$appliance_dir")
  echo "Checking: ${appliance_name}"

  # Check for required config.yaml
  if [[ ! -f "${appliance_dir}/config.yaml" ]]; then
    echo "  ✗ Missing config.yaml"
    ((errors++))
  else
    echo "  ✓ config.yaml found"

    # Basic YAML validation
    if [[ "$YAMLLINT_AVAILABLE" == "true" ]]; then
      if yamllint -d relaxed "${appliance_dir}/config.yaml" >/dev/null 2>&1; then
        echo "    ✓ Valid YAML syntax"
      else
        echo "    ✗ Invalid YAML syntax"
        yamllint -d relaxed "${appliance_dir}/config.yaml" 2>&1 | head -5
        ((errors++))
      fi
    fi

    # Check for required cloud-init.user-data
    if [[ "$YQ_AVAILABLE" == "true" ]]; then
      USER_DATA=$(yq -r '.config."cloud-init.user-data" // ""' "${appliance_dir}/config.yaml" 2>/dev/null || echo "")
      if [[ -z "$USER_DATA" ]]; then
        echo "    ✗ Missing cloud-init.user-data in config"
        ((errors++))
      else
        echo "    ✓ cloud-init.user-data present"

        # Check for #cloud-config header
        if echo "$USER_DATA" | head -1 | grep -q "^#cloud-config"; then
          echo "    ✓ Has #cloud-config header"
        else
          echo "    ✗ Missing #cloud-config header"
          ((errors++))
        fi

        # Check for packages section
        if echo "$USER_DATA" | grep -q "packages:"; then
          echo "    ✓ Has packages section"
        else
          echo "    ⚠ No packages defined"
          ((warnings++))
        fi

        # Check for runcmd section
        if echo "$USER_DATA" | grep -q "runcmd:"; then
          echo "    ✓ Has runcmd section"
        fi
      fi
    fi
  fi

  # Check for appliance.yaml (recommended but not required)
  if [[ ! -f "${appliance_dir}/appliance.yaml" ]]; then
    echo "  ⚠ Missing appliance.yaml (recommended)"
    ((warnings++))
  else
    echo "  ✓ appliance.yaml found"

    # Validate appliance.yaml syntax
    if [[ "$YAMLLINT_AVAILABLE" == "true" ]]; then
      if yamllint -d relaxed "${appliance_dir}/appliance.yaml" >/dev/null 2>&1; then
        echo "    ✓ Valid YAML syntax"
      else
        echo "    ✗ Invalid YAML syntax"
        yamllint -d relaxed "${appliance_dir}/appliance.yaml" 2>&1 | head -5
        ((errors++))
      fi
    fi

    # Basic field checking
    for field in name version description; do
      if grep -q "^${field}:" "${appliance_dir}/appliance.yaml"; then
        echo "    ✓ Has ${field}"
      else
        echo "    ⚠ Missing ${field}"
        ((warnings++))
      fi
    done
  fi

  # Check for README (recommended)
  if [[ ! -f "${appliance_dir}/README.md" ]]; then
    echo "  ⚠ Missing README.md (recommended)"
    ((warnings++))
  else
    echo "  ✓ README.md found"
  fi

  # Check if files directory exists (optional)
  if [[ -d "${appliance_dir}/files" ]]; then
    file_count=$(find "${appliance_dir}/files" -type f | wc -l)
    echo "  ✓ files/ directory exists (${file_count} files)"
  fi

  echo ""
done

echo "==> Validation complete"
echo "    Errors: ${errors}"
echo "    Warnings: ${warnings}"

if [[ $errors -gt 0 ]]; then
  echo ""
  echo "Validation failed with ${errors} error(s)"
  exit 1
fi

exit 0
