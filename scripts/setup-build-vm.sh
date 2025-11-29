#!/usr/bin/env bash
set -euo pipefail

# Setup an Incus VM for building appliances
# This VM will have distrobuilder installed and the project directory mounted

VM_NAME="${1:-appliance-builder}"
CPU="${CPU:-4}"
MEMORY="${MEMORY:-4GiB}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPO_URL="$(git -C "$PROJECT_ROOT" config --get remote.origin.url)"

echo "==> Setting up build VM: ${VM_NAME}"

# Check if Incus is installed
if ! command -v incus &> /dev/null; then
  echo "Error: incus command not found. Please install Incus first."
  echo "  sudo snap install incus --channel=latest/stable"
  exit 1
fi

# Check if VM already exists
if incus list --format csv --columns n | grep -q "^${VM_NAME}$"; then
  echo "Error: VM '${VM_NAME}' already exists"
  echo "To recreate, first run: incus delete -f ${VM_NAME}"
  exit 1
fi

# Create the VM
echo "==> Creating VM with ${CPU} CPUs and ${MEMORY} memory..."
incus launch images:ubuntu/24.04/cloud "$VM_NAME" --vm \
  -c limits.cpu="$CPU" \
  -c limits.memory="$MEMORY" \
  << 'EOF'
config:
  cloud-init.user-data: |
    #cloud-config
    users: []
    package_update: true
    package_upgrade: true
    packages:
    - git
    - ca-certificates
    - curl
    - gnupg
    - unattended-upgrades
    runcmd:
    - systemctl enable unattended-upgrades
    - systemctl start unattended-upgrades
    # Add Zabbly repository for Incus tools
    - mkdir -p /etc/apt/keyrings
    - curl -fsSL https://pkgs.zabbly.com/key.asc -o /etc/apt/keyrings/zabbly.asc
    - |
      cat > /etc/apt/sources.list.d/zabbly-incus-stable.sources <<'ZABBLY_EOF'
      Enabled: yes
      Types: deb
      URIs: https://pkgs.zabbly.com/incus/stable
      Suites: $(. /etc/os-release && echo ${VERSION_CODENAME})
      Components: main
      Architectures: $(dpkg --print-architecture)
      Signed-By: /etc/apt/keyrings/zabbly.asc
      ZABBLY_EOF
    - apt-get update
    - apt-get install -y incus-extra
EOF

# Wait for VM to be ready
echo "==> Waiting for VM to boot and cloud-init to complete..."
for i in {1..60}; do
  if incus exec "$VM_NAME" -- cloud-init status --wait 2>/dev/null; then
    break
  fi
  if [ "$i" -eq 60 ]; then
    echo "Error: VM failed to become ready"
    exit 1
  fi
  sleep 2
done

# Clone project repository inside the VM
echo "==> Cloning project repository inside the VM..."
incus exec "$VM_NAME" -- git clone --filter=blob:none --sparse "$REPO_URL" incus-appliance 2<&1 || {
  echo "Error: Failed to clone project repository inside VM"
  exit 1
}
incus exec "$VM_NAME" -- bash -c "cd incus-appliance && git sparse-checkout set bin appliances" 2<&1 || {
  echo "Error: Failed to set sparse checkout inside VM"
  exit 1
}
