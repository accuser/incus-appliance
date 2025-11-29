# Building with a VM

## Why a VM is Required

`distrobuilder` requires kernel-level privileges that are not available in containers (even privileged ones):
- Creating and mounting loop devices
- Using chroot environments
- Modifying filesystem namespaces
- Direct block device access

These operations require a full kernel, which means builds must run either:
1. **On bare metal** — Direct host access
2. **In a VM** — Full virtualized kernel (recommended for development)

Containers (including Docker and Incus system containers) cannot provide these capabilities.

## Build VM Strategy

### Option 1: Automated Build VM (Recommended)

Use the provided script to automatically create and configure an Incus VM for building:

```bash
# Create and provision the build VM
./scripts/setup-build-vm.sh

# This creates a VM named "appliance-builder" with:
# - Ubuntu 24.04 LTS
# - distrobuilder and incus-simplestreams installed
# - Project directory mounted via virtiofs
# - SSH access configured
```

Once set up, use the remote build wrapper:

```bash
# Build appliances using the VM
./scripts/build-remote.sh nginx
./scripts/build-remote.sh nginx arm64

# Build all appliances
./scripts/build-all-remote.sh

# The VM automatically mounts your project directory, so:
# - Built images go to ./registry/
# - Build artifacts go to ./.build/
# - You can edit appliance templates locally
```

### Option 2: Manual VM Setup

If you prefer to manually configure the VM:

```bash
# 1. Create Ubuntu VM
incus launch images:ubuntu/24.04 appliance-builder --vm -c limits.cpu=4 -c limits.memory=4GiB

# 2. Wait for cloud-init to complete
incus exec appliance-builder -- cloud-init status --wait

# 3. Install dependencies
incus exec appliance-builder -- bash <<'EOF'
apt-get update
apt-get install -y snapd
snap install distrobuilder --classic
snap install incus-simplestreams --classic
EOF

# 4. Mount project directory (virtiofs)
incus config device add appliance-builder project disk \
  source=/path/to/incus-appliance \
  path=/mnt/project

# 5. Run builds in the VM
incus exec appliance-builder -- bash -c 'cd /mnt/project && sudo ./bin/build-appliance.sh nginx'
```

### Option 3: Dedicated Build Server

For production builds, use a dedicated VM or bare metal server:

1. Provision Ubuntu 24.04 server
2. Install distrobuilder and incus-simplestreams:
   ```bash
   snap install distrobuilder --classic
   snap install incus-simplestreams --classic
   ```
3. Clone the repository
4. Run builds with sudo:
   ```bash
   sudo ./bin/build-appliance.sh <name>
   ```

## Build VM Architecture

### Directory Sharing

The build VM mounts your project directory, allowing seamless development:

```
Host (container/laptop)          Build VM
├── appliances/            <-->  /mnt/project/appliances/
├── scripts/               <-->  /mnt/project/scripts/
├── .build/                <-->  /mnt/project/.build/
└── registry/              <-->  /mnt/project/registry/
```

Changes on the host are immediately visible in the VM and vice versa.

### Build Flow

```
1. Developer edits appliance YAML on host
2. Runs ./scripts/build-remote.sh nginx
3. Script executes build inside VM via incus exec
4. distrobuilder builds image in VM
5. Output written to shared directory
6. Registry updated on host filesystem
7. Developer tests locally with ./scripts/serve-local.sh
```

### Resource Allocation

Default VM configuration:
- **CPU**: 4 cores
- **Memory**: 4 GiB
- **Disk**: 20 GiB (root volume)

Adjust based on workload:

```bash
# Increase resources for faster parallel builds
incus config set appliance-builder limits.cpu=8
incus config set appliance-builder limits.memory=8GiB
```

## Development Workflow

### Local Development with Build VM

```bash
# 1. One-time setup
./scripts/setup-build-vm.sh

# 2. Make changes to appliance templates
vim appliances/nginx/image.yaml

# 3. Build using VM
./scripts/build-remote.sh nginx

# 4. Test locally
./scripts/serve-local.sh &
incus remote add test https://localhost:8443 --protocol simplestreams --accept-certificate
incus launch test:nginx test-instance

# 5. Verify
incus exec test-instance -- curl -sf http://localhost || echo "Failed"

# 6. Clean up
incus delete -f test-instance
```

### CI/CD Integration

For automated builds in CI/CD:

```yaml
# GitHub Actions example
- name: Setup Incus VM for building
  run: |
    sudo snap install incus --channel=latest/stable
    sudo incus admin init --auto
    ./scripts/setup-build-vm.sh

- name: Build all appliances
  run: ./scripts/build-all-remote.sh

- name: Publish registry
  run: ./scripts/publish.sh
```

## Troubleshooting

### VM won't start

```bash
# Check if virtualization is available
grep -E 'vmx|svm' /proc/cpuinfo

# Check Incus VM support
incus info | grep "virtual machines"

# Enable VM support if needed
incus admin init  # Choose "yes" for VM support
```

### Mount not working

```bash
# Verify device is attached
incus config device show appliance-builder

# Re-add the mount
incus config device remove appliance-builder project
incus config device add appliance-builder project disk \
  source=$(pwd) \
  path=/mnt/project
```

### Build fails with permission errors

```bash
# Ensure build runs with sudo inside VM
incus exec appliance-builder -- bash -c "cd incus-appliance && sudo ./bin/build-appliance.sh nginx"
```

### VM consumes too much disk

```bash
# Clean build artifacts
incus exec appliance-builder -- rm -rf /mnt/project/.build/*
incus exec appliance-builder -- rm -rf /mnt/project/.cache/distrobuilder/*
```

## Performance Tips

1. **Use local caching**: The `.cache/distrobuilder/` directory speeds up subsequent builds significantly
2. **Parallel builds**: Allocate more CPU cores for building multiple appliances
3. **Keep VM running**: Starting/stopping the VM adds overhead; keep it running during development
4. **Use virtiofs**: The default mount method is already optimized for performance

## Alternative: Remote Build Server

If you don't want a local VM, use SSH to a remote build server:

```bash
# Set environment variable
export BUILD_HOST=user@buildserver.example.com

# Build remotely via SSH
./scripts/build-remote.sh nginx

# The script will:
# - rsync appliance files to remote
# - Execute build on remote server
# - rsync built images back
```

This approach requires manual setup of the remote server with distrobuilder.
