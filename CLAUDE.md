# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **Incus Appliance Registry** — a self-hosted SimpleStreams image server that provides pre-configured system container appliances for Incus. It allows launching single-purpose containers with Docker-like convenience while maintaining the benefits of system containers.

The project generates a static SimpleStreams registry (JSON + image files) that Incus clients can fetch from via HTTPS.

## Build Commands

### Building Appliances

Appliances are built using Incus directly with cloud-init for configuration. Builds require:
1. **Incus installed and running** on the build host
2. **incus-simplestreams** for managing the SimpleStreams registry

```bash
# Build a single appliance
./bin/build-appliance-incus.sh <appliance-name> [architecture]
./bin/build-appliance-incus.sh nginx
./bin/build-appliance-incus.sh nginx arm64

# Build all appliances
./bin/build-all.sh
```

The build process:
1. Launches a container from `images:debian/12/cloud`
2. Applies cloud-init configuration from `config.yaml`
3. Copies files from `files/` directory
4. Stops, publishes, and exports the image
5. Adds to the SimpleStreams registry

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
- **GitHub Pages** — Complete SimpleStreams registry (JSON metadata + image files) + landing page
- **GitHub Releases** — Backup copies of image files (for direct download)

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
2. **cloud-init** = Cloud instance initialization tool used to configure appliances
3. **SimpleStreams** = Protocol for serving image metadata (index.json → images.json → image files)
4. **incus-simplestreams** = CLI tool for managing SimpleStreams registries

### Build Pipeline

```
appliance.yaml + config.yaml + files/
    ↓
Incus (launches container, applies cloud-init, exports image)
    ↓
incus-simplestreams add (adds to registry/, updates JSON metadata)
    ↓
registry/ (served via HTTPS)
    ↓
Incus client fetches and launches
```

### Directory Structure

- **`appliances/`** — Appliance definitions (each in its own directory)
  - **`<name>/`** — Each appliance directory contains:
    - `appliance.yaml` — Metadata (version, ports, healthcheck, etc.)
    - `config.yaml` — Incus/cloud-init configuration (required)
    - `files/` — Additional files to copy into the image
    - `README.md` — User documentation

- **`bin/`** — Core build and test scripts
  - `build-appliance-incus.sh` — Build single appliance using Incus
  - `build-all.sh` — Build all appliances
  - `validate.sh` — Template validation
  - `test-appliance.sh` — Integration testing

- **`scripts/`** — Host orchestration and deployment
  - `serve-local.sh` — Local test server
  - `setup-build-vm.sh` — Create build VM
  - `build-remote.sh` — Build using VM
  - `publish.sh` — Deploy to production

- **`registry/`** — Generated SimpleStreams registry (gitignored)
  - `streams/v1/index.json` — Entry point
  - `streams/v1/images.json` — Image catalog
  - `images/<fingerprint>/` — Image files

- **`.build/`** — Build artifacts (gitignored)
  - `.build/<appliance>/<arch>/` — Per-appliance build directory


### Appliance Template Structure

Every appliance has two YAML files:

**appliance.yaml** (metadata):
```yaml
name: myapp
version: "1.0.0"
description: "Brief description"
cloud_init: true
ports:
  - port: 80
    protocol: tcp
    description: HTTP
volumes:
  - path: /var/lib/myapp
    description: "Application data"
healthcheck:
  command: "curl -sf http://localhost/health || exit 1"
```

**config.yaml** (cloud-init configuration, required):
```yaml
config:
  cloud-init.user-data: |
    #cloud-config
    package_update: true
    packages:
      - nginx
    write_files:
      - path: /etc/myapp/config.yaml
        permissions: '0644'
        content: |
          # configuration here
    runcmd:
      - systemctl enable myapp
      - systemctl start myapp
```

### cloud-init Modules

The `config.yaml` uses cloud-init's cloud-config format:
- **packages**: List of packages to install
- **write_files**: Files to create with content and permissions
- **users**: Create system users
- **runcmd**: Commands to run after boot

## Creating New Appliances

### Quick Start

```bash
# 1. Create directory structure
mkdir -p appliances/myapp/files

# 2. Create appliance.yaml (see appliances/nginx/appliance.yaml as reference)

# 3. Create config.yaml with cloud-init configuration

# 4. Add any files to files/ directory (optional)

# 5. Create README.md documenting usage

# 6. Build and test
./bin/build-appliance-incus.sh myapp
./bin/test-appliance.sh myapp appliance-test
```

### Best Practices

- **Use cloud-init write_files** — Embed configuration files directly in config.yaml when possible
- **No default passwords** — Use cloud-init for credentials at launch time
- **Run services as non-root** — Create dedicated users in cloud-init users section
- **Include health checks** — Define working health check in appliance.yaml
- **Document persistence** — Clearly specify which directories should be persisted in volumes
- **Keep packages minimal** — Only install what's necessary

### Base Image

All appliances are built from `images:debian/12/cloud` which includes:
- Debian 12 (Bookworm)
- cloud-init pre-installed
- systemd for service management
- Minimal footprint

## Testing Workflow

1. **Build** — `./bin/build-appliance-incus.sh <name>`
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

- **Incus must be installed** and running on the build host
- **incus-simplestreams** must be installed for registry management
- The user must have permissions to use Incus (member of `incus` group or root)
- First build downloads the base image from linuxcontainers.org (cached by Incus)
- Subsequent builds are faster due to image caching

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

- **"Incus not found"** — Ensure Incus is installed and running
- **"Permission denied"** — User must be in the `incus` group
- **cloud-init timeout** — Check cloud-init logs in the container
- **Package not found** — Verify package name in Debian repositories
- **Service won't start** — Check systemd unit file syntax

### Template Issues

- **Validation fails** — Ensure `config.yaml` exists and has `cloud-init.user-data`
- **Missing #cloud-config header** — First line of user-data must be `#cloud-config`
- **YAML syntax errors** — Run `./bin/validate.sh` or `make lint`

### Testing Issues

- **Image not in remote** — Rebuild and check `incus image list appliance-test:`
- **Instance won't start** — Check logs with `incus info <instance> --show-log`
- **Health check fails** — Verify service is running and health endpoint is accessible

## Documentation References

- **User guides**: README.md, QUICKSTART.md
- **Creating appliances**: docs/creating-appliances.md (comprehensive guide with examples)
- **Architecture**: docs/architecture.md (technical deep dive)
- **Deployment**: docs/deployment.md (production deployment options)
- **VM builds**: docs/vm-build-setup.md (building in containers/devcontainers using VMs)
- **Versioning**: docs/versioning.md (semantic versioning policy and image aliases)
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
