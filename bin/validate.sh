#!/usr/bin/env bash
set -euo pipefail

# Validate all appliance templates
# Checks for required files and basic YAML syntax

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APPLIANCES_DIR="${PROJECT_ROOT}/appliances"

errors=0
warnings=0

echo "==> Validating appliance templates..."
echo ""

# Find all appliances (exclude _base)
for appliance_dir in "${APPLIANCES_DIR}"/*; do
  [[ ! -d "$appliance_dir" ]] && continue
  [[ "$(basename "$appliance_dir")" == "_base" ]] && continue

  appliance_name=$(basename "$appliance_dir")
  echo "Checking: ${appliance_name}"

  # Check for required files
  if [[ ! -f "${appliance_dir}/image.yaml" ]]; then
    echo "  ✗ Missing image.yaml"
    ((errors++))
  else
    echo "  ✓ image.yaml found"

    # Basic YAML validation
    if command -v yamllint >/dev/null 2>&1; then
      if yamllint -d relaxed "${appliance_dir}/image.yaml" >/dev/null 2>&1; then
        echo "    ✓ Valid YAML syntax"
      else
        echo "    ✗ Invalid YAML syntax"
        ((errors++))
      fi
    fi

    # Check for required fields in image.yaml
    if ! grep -q "^image:" "${appliance_dir}/image.yaml"; then
      echo "    ✗ Missing 'image:' section"
      ((errors++))
    fi
    if ! grep -q "^source:" "${appliance_dir}/image.yaml"; then
      echo "    ✗ Missing 'source:' section"
      ((errors++))
    fi
    if ! grep -q "^packages:" "${appliance_dir}/image.yaml"; then
      echo "    ⚠ No packages defined"
      ((warnings++))
    fi
  fi

  # Check for appliance.yaml (recommended but not required)
  if [[ ! -f "${appliance_dir}/appliance.yaml" ]]; then
    echo "  ⚠ Missing appliance.yaml (recommended)"
    ((warnings++))
  else
    echo "  ✓ appliance.yaml found"

    # Validate appliance.yaml
    if command -v yamllint >/dev/null 2>&1; then
      if yamllint -d relaxed "${appliance_dir}/appliance.yaml" >/dev/null 2>&1; then
        echo "    ✓ Valid YAML syntax"
      else
        echo "    ✗ Invalid YAML syntax"
        ((errors++))
      fi
    fi

    # Check for recommended fields
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

  # Check if files directory is referenced but missing
  if grep -q "generator: copy" "${appliance_dir}/image.yaml" 2>/dev/null; then
    if [[ ! -d "${appliance_dir}/files" ]]; then
      echo "  ✗ image.yaml references files/ but directory not found"
      ((errors++))
    else
      echo "  ✓ files/ directory exists"
    fi
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
