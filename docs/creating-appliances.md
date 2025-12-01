# Creating Appliances

This guide walks you through creating a new appliance for the Incus Appliance Registry.

## Overview

An appliance consists of:

1. **appliance.yaml** — Metadata about the appliance (optional but recommended)
2. **image.yaml** — Distrobuilder template defining the image build process
3. **files/** — Files to embed in the image
4. **README.md** — User documentation
5. **profiles/** — Optional Incus profiles (optional)

Additionally, you must register your appliance in the root **appliances.yaml** manifest file for it to be built by CI/CD.

## The appliances.yaml Manifest

The root `appliances.yaml` file defines which appliances are built and published by CI/CD. This is separate from the per-appliance `appliance.yaml` metadata files.

### Schema Reference

```yaml
# Default settings applied to all appliances unless overridden
defaults:
  architectures:        # List of architectures to build
    - amd64
    - arm64
  enabled: true         # Whether appliances are enabled by default

# List of appliances to build
appliances:
  - name: myapp                    # Required: Appliance name (must match directory name)
    description: "Description"     # Required: Brief description for registry
    architectures:                 # Optional: Override default architectures
      - amd64
    enabled: true                  # Optional: Set to false to skip building
```

### Field Reference

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `defaults.architectures` | No | `["amd64", "arm64"]` | Default architectures for all appliances |
| `defaults.enabled` | No | `true` | Default enabled state for all appliances |
| `appliances[].name` | **Yes** | — | Appliance name, must match directory in `appliances/` |
| `appliances[].description` | **Yes** | — | Brief description shown in registry and GitHub Pages |
| `appliances[].architectures` | No | Inherits from defaults | Override architectures for this appliance |
| `appliances[].enabled` | No | Inherits from defaults | Set `false` to skip building this appliance |

### How CI/CD Uses This File

The GitHub Actions workflow reads `appliances.yaml` to:

1. **Generate build matrix** — Creates parallel build jobs for each appliance/architecture combination
2. **Filter enabled appliances** — Skips appliances with `enabled: false`
3. **Read versions** — Version is sourced from each appliance's `appliance.yaml` file (not from this manifest)
4. **Generate registry metadata** — Uses descriptions for the SimpleStreams index and GitHub Pages

### Example: Full Manifest

```yaml
# appliances.yaml - Registry manifest

defaults:
  architectures:
    - amd64
    - arm64
  enabled: true

appliances:
  # Production-ready appliances
  - name: nginx
    description: High-performance web server and reverse proxy

  - name: postgres
    description: PostgreSQL database server with replication support

  # Architecture-specific appliance
  - name: arm-optimized-app
    description: Application optimized for ARM processors
    architectures:
      - arm64

  # Temporarily disabled appliance
  - name: experimental-app
    description: Experimental application (under development)
    enabled: false
```

### Adding Your Appliance to the Manifest

After creating your appliance directory and files, add an entry to `appliances.yaml`:

```yaml
appliances:
  # ... existing appliances ...

  - name: myapp
    description: "Brief description of what your appliance does"
```

The version is automatically read from your appliance's `appliances/myapp/appliance.yaml` file during the build process.

## Step-by-Step Guide

### 1. Create Directory Structure

```bash
mkdir -p appliances/myapp/{files,profiles}
cd appliances/myapp
```

### 2. Create appliance.yaml

This file contains metadata about your appliance:

```yaml
name: myapp
version: "1.0.0"
description: "Brief description of your appliance"
maintainer: "Your Name <your@email.com>"

architectures:
  - amd64
  - arm64

types:
  - container

base:
  distribution: debian
  release: bookworm

# cloud-init support (recommended)
cloud_init: true

requirements:
  min_cpu: 1
  min_memory: 128MB
  min_disk: 512MB
  recommended_memory: 256MB
  recommended_disk: 1GB

ports:
  - port: 8080
    protocol: tcp
    description: HTTP API

volumes:
  - path: /var/lib/myapp/data
    description: "Application data"
  - path: /etc/myapp
    description: "Configuration files"

environment:
  - name: MYAPP_PORT
    default: "8080"
    description: "Port to listen on"

healthcheck:
  command: "curl -sf http://localhost:8080/health || exit 1"
  interval: 30s
  timeout: 5s
  retries: 3

tags:
  - database
  - cache
  - web

see_also:
  - similar-app
  - alternative-app
```

### 3. Create image.yaml

This is the distrobuilder template that defines how to build the image:

```yaml
image:
  distribution: debian
  release: bookworm
  description: "MyApp appliance"

source:
  downloader: debootstrap
  url: http://deb.debian.org/debian

packages:
  manager: apt
  update: true
  cleanup: true
  sets:
    - packages:
        # Base system
        - ca-certificates
        - curl
        - tzdata
        - logrotate
        # cloud-init for last-mile configuration
        - cloud-init
        # systemd for service management
        - systemd
        - systemd-sysv
        - dbus
        # Application
        - myapp
      action: install

files:
  - path: /etc/myapp/config.yml
    generator: copy
    source: files/config.yml
    mode: "0644"

  - path: /etc/motd
    generator: dump
    content: |-
      MyApp Appliance
      Configuration: /etc/myapp/
      Logs: /var/log/myapp/

      Supports cloud-init for automated configuration.
    mode: "0644"

  - path: /etc/cloud/cloud.cfg.d/99-incus.cfg
    generator: dump
    content: |-
      datasource_list: [LXD]
      datasource:
        LXD:
          apply_network_config: true
    mode: "0644"

actions:
  - trigger: post-unpack
    action: |-
      # Create necessary directories
      mkdir -p /var/lib/myapp/data
      mkdir -p /var/log/myapp

  - trigger: post-packages
    action: |-
      # Enable service at boot
      systemctl enable myapp

      # Enable cloud-init services
      systemctl enable cloud-init-local.service
      systemctl enable cloud-init.service
      systemctl enable cloud-config.service
      systemctl enable cloud-final.service

      # Disable unnecessary services
      systemctl disable apt-daily.timer || true
      systemctl disable apt-daily-upgrade.timer || true

      # Create user
      useradd -r -s /sbin/nologin myapp

  - trigger: post-files
    action: |-
      # Set permissions
      chown -R myapp:myapp /var/lib/myapp
      chown -R myapp:myapp /var/log/myapp
      chmod 755 /etc/myapp

      # Clean up
      apt-get clean
      rm -rf /var/lib/apt/lists/*
```

## Distribution-Specific Examples

### Debian (Recommended)

Best for: Most appliances — reliable cloud-init support, broad compatibility

```yaml
image:
  distribution: debian
  release: bookworm

source:
  downloader: debootstrap
  url: http://deb.debian.org/debian

packages:
  manager: apt
  update: true
  cleanup: true
```

**Pros**: Native cloud-init support, wide compatibility, glibc, extensive packages
**Cons**: Larger size than Alpine (~100-500MB vs ~20-100MB)

### Ubuntu

Best for: Software with PPAs or requiring newer packages

```yaml
image:
  distribution: ubuntu
  release: jammy

source:
  downloader: ubuntu-http
  url: http://archive.ubuntu.com/ubuntu

packages:
  manager: apt
  update: true
  cleanup: true
```

**Pros**: PPAs, newer packages, commercial support
**Cons**: Larger size, similar to Debian

## File Generators

### copy - Copy Static Files

```yaml
files:
  - path: /etc/nginx/nginx.conf
    generator: copy
    source: files/nginx.conf
    mode: "0644"
```

### dump - Inline Content

```yaml
files:
  - path: /etc/profile.d/myapp.sh
    generator: dump
    content: |-
      export MYAPP_HOME=/opt/myapp
      export PATH=$PATH:$MYAPP_HOME/bin
    mode: "0644"
```

### template - Go Templates

```yaml
files:
  - path: /etc/myapp/config.yml
    generator: template
    template:
      properties:
        hostname: "{{ .Hostname }}"
        release: "{{ .Release }}"
    mode: "0644"
```

## Actions and Triggers

Actions run at different stages of the build:

### post-unpack

Runs after base system is unpacked, before packages:

```yaml
actions:
  - trigger: post-unpack
    action: |-
      # Create directories
      mkdir -p /opt/myapp
      # Download files
      wget -O /tmp/app.tar.gz https://example.com/app.tar.gz
```

### post-packages

Runs after packages are installed:

```yaml
actions:
  - trigger: post-packages
    action: |-
      # Enable services
      systemctl enable myapp

      # Create users
      useradd -r -s /bin/false myapp
```

### post-files

Runs after files are generated:

```yaml
actions:
  - trigger: post-files
    action: |-
      # Set permissions
      chown -R myapp:myapp /var/lib/myapp
      chmod 600 /etc/myapp/secrets.conf

      # Run initialization
      /opt/myapp/bin/init-db
```

## Best Practices

### Security

1. **No default passwords** — Use cloud-init or profiles to set credentials
2. **Principle of least privilege** — Run services as non-root users
3. **Minimal packages** — Only install what's needed
4. **Regular updates** — Pin versions in templates, update regularly
5. **No secrets in images** — Use external configuration

### Size Optimization

1. **Clean package cache** — Enable `cleanup: true` and run `apt-get clean`
2. **Remove unnecessary packages** — Minimal package sets
3. **Multi-stage builds** — Build dependencies in separate container
4. **Compress static content** — Pre-compress large files

### Reliability

1. **Health checks** — Always include a working health check
2. **Graceful shutdown** — Handle SIGTERM properly
3. **Data persistence** — Document which directories to persist
4. **Idempotent actions** — Scripts should be safe to run multiple times
5. **Error handling** — Validate configuration on startup

### Documentation

1. **README.md** — Clear usage examples
2. **Configuration** — Document all environment variables
3. **Networking** — Explain ports and protocols
4. **Troubleshooting** — Common issues and solutions
5. **Examples** — Real-world usage scenarios

## Testing Your Appliance

### 1. Validate Template

```bash
make validate
```

### 2. Build Image

```bash
make build-myapp
```

### 3. Test Launch

```bash
# Start test server
make serve &

# Add remote
incus remote add test https://localhost:8443 --protocol simplestreams --accept-certificate

# Launch
incus launch test:myapp test-instance

# Run tests
make test-myapp
```

### 4. Manual Testing

```bash
# Check logs
incus exec test-instance -- journalctl -u myapp
incus exec test-instance -- cat /var/log/myapp/error.log

# Test service
incus exec test-instance -- systemctl status myapp

# Test health check
incus exec test-instance -- curl -s localhost:8080/health

# Test cloud-init status
incus exec test-instance -- cloud-init status

# Test configuration
incus exec test-instance -- cat /etc/myapp/config.yml

# Interactive shell
incus exec test-instance -- bash
```

## Common Patterns

### Database Appliance

```yaml
volumes:
  - path: /var/lib/postgresql/data
    description: "Database files (MUST be persisted)"

healthcheck:
  command: "pg_isready -U postgres"

environment:
  - name: POSTGRES_PASSWORD
    description: "Database superuser password (set via cloud-init)"
```

### Web Service

```yaml
ports:
  - port: 80
    protocol: tcp
  - port: 443
    protocol: tcp

healthcheck:
  command: "curl -sf http://localhost/health || exit 1"

volumes:
  - path: /etc/nginx/conf.d
    description: "Site configurations"
```

### Caching Service

```yaml
requirements:
  recommended_memory: 1GB

healthcheck:
  command: "redis-cli ping | grep PONG"

environment:
  - name: REDIS_MAXMEMORY
    default: "256mb"
```

## Troubleshooting Build Issues

### Package Not Found

```yaml
# Search Debian packages at: https://packages.debian.org/

# Add backports repository if needed
actions:
  - trigger: post-unpack
    action: |-
      echo "deb http://deb.debian.org/debian bookworm-backports main" >> /etc/apt/sources.list.d/backports.list
```

### Service Won't Start

```yaml
# Check service name
actions:
  - trigger: post-packages
    action: |-
      # List available services
      systemctl list-unit-files
      # Enable the correct one
      systemctl enable myserviced
```

### Permission Errors

```yaml
actions:
  - trigger: post-files
    action: |-
      # Create user first
      useradd -r -s /sbin/nologin myapp
      # Then set ownership
      chown -R myapp:myapp /var/lib/myapp
      # Check permissions
      ls -la /var/lib/myapp
```

### File Not Found

```yaml
# Ensure files directory exists
# appliances/myapp/files/config.yml must exist

files:
  - path: /etc/myapp/config.yml
    generator: copy
    source: files/config.yml  # Relative to appliances/myapp/
```

## Advanced Topics

### Multi-Architecture Builds

```bash
# Build for specific arch
make build-myapp ARCH=arm64

# Image.yaml uses variable
image:
  architecture: ${ARCH}
```

### Custom Repositories

```yaml
# Debian backports
actions:
  - trigger: post-unpack
    action: |-
      echo "deb http://deb.debian.org/debian bookworm-backports main" >> /etc/apt/sources.list.d/backports.list
      apt-get update
```

### Cloud-init Integration

Cloud-init is recommended for all appliances. Configure the Incus/LXD datasource:

```yaml
# Include cloud-init
packages:
  sets:
    - packages:
        - cloud-init
      action: install

# Configure cloud-init for Incus
files:
  - path: /etc/cloud/cloud.cfg.d/99-incus.cfg
    generator: dump
    content: |-
      datasource_list: [LXD]
      datasource:
        LXD:
          apply_network_config: true

# Enable cloud-init services in post-packages
actions:
  - trigger: post-packages
    action: |-
      systemctl enable cloud-init-local.service
      systemctl enable cloud-init.service
      systemctl enable cloud-config.service
      systemctl enable cloud-final.service
```

Users can then configure appliances at launch time:

```bash
incus init appliance:myapp my-instance
incus config set my-instance cloud-init.user-data - << 'EOF'
#cloud-config
write_files:
  - path: /etc/myapp/config.yml
    content: |
      setting: value
runcmd:
  - systemctl restart myapp
EOF
incus start my-instance
```

## Contributing Guidelines

When submitting a new appliance:

1. **Register in manifest** — Add entry to root `appliances.yaml`
2. **Test thoroughly** — Build and launch successfully
3. **Document well** — Complete README.md with examples
4. **Follow conventions** — Use existing appliances as templates
5. **Health checks** — Always include working health check
6. **Security review** — No passwords, minimal attack surface
7. **Enable cloud-init** — Include cloud-init for last-mile configuration
8. **Metadata complete** — Fill out appliance.yaml completely

## Example Appliances

Study these reference implementations:

- [nginx](../appliances/nginx/) — Minimal, well-documented
- More examples coming soon

## Getting Help

- Check existing appliances for examples
- Open an issue for questions
- Join discussions in GitHub Discussions
