#!/usr/bin/env bash
set -euo pipefail

# Validate all appliance templates
# Checks for required files, YAML syntax, and JSON schema validation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APPLIANCES_DIR="${PROJECT_ROOT}/appliances"
SCHEMAS_DIR="${PROJECT_ROOT}/schemas"

errors=0
warnings=0

# Check if schema validation tools are available
SCHEMA_VALIDATION=false
if command -v check-jsonschema >/dev/null 2>&1 && command -v yq >/dev/null 2>&1; then
  SCHEMA_VALIDATION=true
  echo "==> Schema validation enabled (check-jsonschema + yq found)"
elif command -v yq >/dev/null 2>&1; then
  echo "==> Schema validation disabled (install check-jsonschema for full validation)"
  echo "    Install with: pip install check-jsonschema"
else
  echo "==> Schema validation disabled (yq and check-jsonschema not found)"
fi
echo ""

# Validate root appliances.yaml if it exists
if [[ -f "${PROJECT_ROOT}/appliances.yaml" ]]; then
  echo "==> Validating appliances.yaml manifest..."

  # YAML syntax check
  if command -v yamllint >/dev/null 2>&1; then
    if yamllint -d relaxed "${PROJECT_ROOT}/appliances.yaml" >/dev/null 2>&1; then
      echo "  ✓ Valid YAML syntax"
    else
      echo "  ✗ Invalid YAML syntax"
      yamllint -d relaxed "${PROJECT_ROOT}/appliances.yaml" 2>&1 | head -10
      ((errors++))
    fi
  fi

  # Schema validation
  if [[ "$SCHEMA_VALIDATION" == "true" ]] && [[ -f "${SCHEMAS_DIR}/appliances.schema.json" ]]; then
    if yq -o=json "${PROJECT_ROOT}/appliances.yaml" | check-jsonschema --schemafile "${SCHEMAS_DIR}/appliances.schema.json" - 2>/dev/null; then
      echo "  ✓ Valid against schema"
    else
      echo "  ✗ Schema validation failed"
      yq -o=json "${PROJECT_ROOT}/appliances.yaml" | check-jsonschema --schemafile "${SCHEMAS_DIR}/appliances.schema.json" - 2>&1 | head -20
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

    # Validate appliance.yaml syntax
    if command -v yamllint >/dev/null 2>&1; then
      if yamllint -d relaxed "${appliance_dir}/appliance.yaml" >/dev/null 2>&1; then
        echo "    ✓ Valid YAML syntax"
      else
        echo "    ✗ Invalid YAML syntax"
        ((errors++))
      fi
    fi

    # Schema validation for appliance.yaml
    if [[ "$SCHEMA_VALIDATION" == "true" ]] && [[ -f "${SCHEMAS_DIR}/appliance.schema.json" ]]; then
      if yq -o=json "${appliance_dir}/appliance.yaml" | check-jsonschema --schemafile "${SCHEMAS_DIR}/appliance.schema.json" - 2>/dev/null; then
        echo "    ✓ Valid against schema"
      else
        echo "    ✗ Schema validation failed"
        yq -o=json "${appliance_dir}/appliance.yaml" | check-jsonschema --schemafile "${SCHEMAS_DIR}/appliance.schema.json" - 2>&1 | head -10
        ((errors++))
      fi
    else
      # Fallback to basic field checking
      for field in name version description; do
        if grep -q "^${field}:" "${appliance_dir}/appliance.yaml"; then
          echo "    ✓ Has ${field}"
        else
          echo "    ⚠ Missing ${field}"
          ((warnings++))
        fi
      done
    fi
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
