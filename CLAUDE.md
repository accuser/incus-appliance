# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **Incus Appliance Registry** — a self-hosted SimpleStreams image server that provides pre-configured system container appliances for Incus. It allows launching single-purpose containers with Docker-like convenience while maintaining the benefits of system containers.

The project generates a static SimpleStreams registry (JSON + image files) that Incus clients can fetch from via HTTPS.

## Build Commands

### Building Appliances

**IMPORTANT**: `distrobuilder` requires kernel-level access and **cannot run in containers** (including Docker and Incus system containers). Builds must run either:
1. **On bare metal** with `sudo` (if you have direct host access)
2. **In a VM** (recommended for development environments like devcontainers)

#### Option 1: Building with a VM (Recommended for Containers/Devcontainers)

If you're running in a container or devcontainer, use the build VM approach:

```bash
# One-time setup: Create and configure build VM
./scripts/setup-build-vm.sh

# Build a single appliance using the VM
./scripts/build-remote.sh <appliance-name> [architecture]
./scripts/build-remote.sh nginx
./scripts/build-remote.sh nginx arm64

# Build all appliances using the VM
./scripts/build-all-remote.sh [architecture]
```

The VM automatically mounts your project directory, so built images appear in your local `registry/` directory.

See [docs/vm-build-setup.md](docs/vm-build-setup.md) for detailed VM setup and usage.

#### Option 2: Building on Bare Metal

If running directly on a host with Incus installed:

```bash
# Build a single appliance
sudo ./bin/build-appliance.sh <appliance-name> [architecture]
# Or via Makefile
make build-nginx                    # Build nginx for current arch
make build-nginx ARCH=arm64        # Build for specific arch

# Build all appliances
sudo ./bin/build-all.sh
# Or via Makefile
make build                         # Build all for current arch
make build-all-arch               # Build all for amd64 and arm64
```

### Validation and Testing

```bash
# Validate all appliance templates
./bin/validate.sh
make validate

# Lint YAML files (requires yamllint)
make lint

# Test single appliance
./bin/test-appliance.sh <appliance-name> [remote-name]
make test-nginx

# Test all appliances
./bin/test-all.sh
make test
```

### Local Development Server

```bash
# Start local HTTPS test server (serves registry on https://localhost:8443)
./scripts/serve-local.sh
make serve

# In another terminal, add the test remote
incus remote add appliance-test https://localhost:8443 --protocol simplestreams --accept-certificate

# Launch from test remote
incus launch appliance-test:nginx test-instance
```

### Publishing the Registry

#### Option 1: Automatic Publishing via GitHub Actions (Recommended)

The repository includes a GitHub Actions workflow that automatically builds and publishes appliances:

1. **Enable GitHub Pages** in repository settings (Settings → Pages → Source: GitHub Actions)
2. **Push changes** to appliances — the workflow automatically:
   - Builds all appliances
   - Uploads image files to GitHub Releases (`latest` tag)
   - Publishes SimpleStreams metadata to GitHub Pages
3. **Access your registry** at: `https://<username>.github.io/<repo-name>`

Users can then add your registry:
```bash
incus remote add myregistry https://username.github.io/incus-appliance --protocol simplestreams
incus launch myregistry:nginx my-nginx
```

**What gets published:**
- **GitHub Pages** — SimpleStreams JSON files (index.json, images.json) + landing page
- **GitHub Releases** — Actual image files (incus.tar.xz, rootfs.squashfs)

#### Option 2: Manual Publishing to Your Own Server

When building with the VM, the registry is created inside the VM. You need to pull it to your host before publishing:

```bash
# 1. Pull registry from VM to host
./scripts/pull-registry.sh

# 2. Deploy to production (requires PUBLISH_DEST or argument)
./scripts/publish.sh user@server:/var/www/appliances

# Using environment variables
PUBLISH_METHOD=rsync PUBLISH_DEST=user@server:/var/www/appliances ./scripts/publish.sh
PUBLISH_METHOD=s3 PUBLISH_DEST=s3://bucket/path ./scripts/publish.sh
```

**Publishing Methods:**
- `rsync` (default) — Sync to remote server via SSH
- `s3` — Upload to AWS S3 bucket
- `custom` — Use custom publish script at `scripts/publish-custom.sh`

### Cleanup

```bash
make clean          # Remove .build/ directory
make clean-all      # Remove .build/ and registry/
```

## Architecture

### Key Concepts

1. **Appliance** = Pre-configured single-purpose container image
2. **distrobuilder** = Tool that builds images from YAML templates
3. **SimpleStreams** = Protocol for serving image metadata (index.json → images.json → image files)
4. **incus-simplestreams** = CLI tool for managing SimpleStreams registries

### Build Pipeline

```
appliance.yaml + image.yaml + files/
    ↓
distrobuilder (creates incus.tar.xz + rootfs.squashfs)
    ↓
incus-simplestreams add (adds to registry/, updates JSON metadata)
    ↓
registry/ (served via HTTPS)
    ↓
Incus client fetches and launches
```

### Directory Structure

- **`appliances/`** — Appliance definitions (each in its own directory)
  - **`_base/`** — Shared base templates (alpine.yaml, debian.yaml)
  - **`<name>/`** — Each appliance directory contains:
    - `appliance.yaml` — Metadata (optional but recommended)
    - `image.yaml` — Distrobuilder build template (required)
    - `files/` — Files to embed in the image
    - `README.md` — User documentation
    - `profiles/` — Optional Incus profiles

- **`scripts/`** — Build, test, and deployment automation
  - `build-appliance.sh` — Core build script
  - `serve-local.sh` — Local test server
  - `validate.sh` — Template validation
  - `test-appliance.sh` — Integration testing

- **`registry/`** — Generated SimpleStreams registry (gitignored)
  - `streams/v1/index.json` — Entry point
  - `streams/v1/images.json` — Image catalog
  - `images/<fingerprint>/` — Image files

- **`.build/`** — Build artifacts (gitignored)
  - `.build/<appliance>/<arch>/` — Per-appliance build directory

- **`.cache/distrobuilder/`** — Base image cache (gitignored)

### Appliance Template Structure

Every appliance has two YAML files:

**appliance.yaml** (metadata, optional but recommended):
```yaml
name: myapp
version: "1.0.0"
description: "Brief description"
base:
  distribution: alpine
  release: "3.20"
ports: [...]
volumes: [...]
healthcheck:
  command: "curl -sf http://localhost/health || exit 1"
```

**image.yaml** (distrobuilder template, required):
```yaml
image:           # Image metadata (distribution, release, architecture)
source:          # Where to download base image
packages:        # Packages to install/remove
files:           # Files to inject (copy, dump, or template)
actions:         # Scripts to run at build stages (post-unpack, post-packages, post-files)
```

### File Generators in image.yaml

- **copy**: Copy from `files/` directory
- **dump**: Inline content
- **template**: Go templates with variables

### Action Triggers

- **post-unpack**: After base system unpacked, before packages
- **post-packages**: After package installation
- **post-files**: After file generation

## Creating New Appliances

### Quick Start

```bash
# 1. Create directory structure
mkdir -p appliances/myapp/{files,profiles}

# 2. Create appliance.yaml (see appliances/nginx/appliance.yaml as reference)

# 3. Create image.yaml (see appliances/nginx/image.yaml as reference)

# 4. Add any files to files/ directory

# 5. Create README.md documenting usage

# 6. Build and test
sudo ./bin/build-appliance.sh myapp
./bin/test-appliance.sh myapp appliance-test
```

### Best Practices

- **Use Alpine when possible** — Results in 5-10x smaller images
- **No default passwords** — Use cloud-init or profiles for credentials
- **Run services as non-root** — Create dedicated users in post-packages action
- **Enable cleanup** — Set `packages.cleanup: true` to remove package cache
- **Include health checks** — Define working health check in appliance.yaml
- **Document persistence** — Clearly specify which directories should be persisted in volumes

### Distribution-Specific Notes

**Alpine Linux** (preferred for small appliances):
- Init: OpenRC (`rc-update add service default`)
- Package manager: apk
- C library: musl (some software may be incompatible)

**Debian/Ubuntu** (for complex applications):
- Init: systemd (`systemctl enable service`)
- Package manager: apt
- C library: glibc (broader compatibility)

## Testing Workflow

1. **Build** — `sudo ./bin/build-appliance.sh <name>`
2. **Start server** — `./scripts/serve-local.sh &`
3. **Add remote** — `incus remote add test https://localhost:8443 --protocol simplestreams --accept-certificate`
4. **Launch** — `incus launch test:<name> test-instance`
5. **Verify** — Check service is running and health check passes
6. **Test script** — Run `./bin/test-appliance.sh <name> test` for automated testing
7. **Cleanup** — `incus delete -f test-instance`

## Critical Implementation Details

### Architecture Normalization

The build script normalizes architecture names:
- `x86_64` → `amd64`
- `aarch64` → `arm64`

### Build Requirements

- **Container limitation**: `distrobuilder` cannot run in containers (Docker or Incus system containers)
  - Requires kernel features unavailable to containers (loop devices, chroot, mount namespaces)
  - **Solution**: Use a VM for building (see [docs/vm-build-setup.md](docs/vm-build-setup.md))
- Builds **must** run with `sudo` (distrobuilder needs root access for chroot operations)
- First build downloads base images (cached in `.cache/distrobuilder/`)
- Subsequent builds are much faster due to caching

### Registry Management

- `incus-simplestreams add` automatically:
  - Calculates image fingerprint (SHA256)
  - Copies files to `registry/images/<fingerprint>/`
  - Updates `streams/v1/images.json`
  - Updates `streams/v1/index.json`

- Aliases are automatically created:
  - `<name>` — Default alias
  - `<name>/<arch>` — Architecture-specific alias

### Test Server Details

- Generates self-signed certificates in `.certs/`
- Serves on port 8443 (configurable via `PORT` env var)
- Uses Python's http.server with SSL
- Must use `--accept-certificate` flag when adding remote (self-signed cert)

## Common Pitfalls

### Build Failures

- **"Permission denied"** — Build scripts must run with `sudo`
- **"distrobuilder not found"** — Install with `sudo snap install distrobuilder --classic`
- **Package not found** — Check distribution's package repository (Alpine may need community repo enabled)
- **Service won't start** — Verify service name matches init system (OpenRC: `/etc/init.d/<name>`, systemd: `<name>.service`)

### Template Issues

- **Files not found** — `source:` path in `files:` section is relative to `appliances/<name>/`
- **Validation fails** — Ensure `image.yaml` exists and has `image:` and `source:` sections
- **YAML syntax errors** — Run `make lint` if yamllint is installed

### Testing Issues

- **Image not in remote** — Rebuild and check `incus image list appliance-test:`
- **Instance won't start** — Check logs with `incus info <instance> --show-log`
- **Health check fails** — Verify service is running and health endpoint is accessible

## Documentation References

- **User guides**: README.md, QUICKSTART.md, GETTING_STARTED.md
- **Creating appliances**: docs/creating-appliances.md (comprehensive guide with examples)
- **Architecture**: docs/architecture.md (technical deep dive)
- **Deployment**: docs/deployment.md (production deployment options)
- **VM builds**: docs/vm-build-setup.md (building in containers/devcontainers using VMs)
- **Contributing**: CONTRIBUTING.md (contribution guidelines and standards)

## Shell Script Standards

All scripts in `bin/` and `scripts/` follow these conventions:
- Shebang: `#!/usr/bin/env bash`
- Safety: `set -euo pipefail`
- Usage: Include usage message when arguments are missing
- Variables: Use `${VAR}` syntax, validate required args with `${VAR:?message}`
- Errors: Echo to stderr and exit with non-zero code
- Paths: Use `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)` for script directory

## Development Workflow (GitHub Flow)

This project uses **GitHub Flow** for all changes:

### Making Changes

1. **Create a feature branch** from `main`:
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/my-feature
   ```

2. **Make your changes** and commit regularly:
   ```bash
   git add .
   git commit -m "Description of changes"
   ```

3. **Push your branch** to GitHub:
   ```bash
   git push -u origin feature/my-feature
   ```

4. **Create a Pull Request** on GitHub:
   - Go to the repository on GitHub
   - Click "Pull requests" → "New pull request"
   - Select your feature branch
   - Fill in the PR description
   - Request review if needed

5. **CI checks must pass**:
   - Template validation
   - Shell script linting (shellcheck)
   - Build test (nginx appliance)

6. **Merge to main**:
   - Use "Squash and merge" to keep history clean
   - Delete the feature branch after merging

### Branch Naming Conventions

- `feature/` - New features or enhancements
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `refactor/` - Code refactoring
- `test/` - Test additions or improvements

### Commit Message Guidelines

- Use imperative mood ("Add feature" not "Added feature")
- Keep first line under 72 characters
- Reference issues/PRs when applicable
- Be descriptive but concise

### Examples

```bash
# Add a new appliance
git checkout -b feature/postgres-appliance
# ... make changes ...
git commit -m "Add PostgreSQL appliance with replication support"
git push -u origin feature/postgres-appliance
# Create PR on GitHub

# Fix a bug
git checkout -b fix/nginx-permissions
# ... make changes ...
git commit -m "Fix nginx log directory permissions"
git push -u origin fix/nginx-permissions
# Create PR on GitHub
```
