# Creating Appliances

This guide walks you through creating a new appliance for the Incus Appliance Registry.

## Overview

An appliance consists of:

1. **appliance.yaml** — Metadata about the appliance (version, ports, healthcheck, etc.)
2. **config.yaml** — Cloud-init configuration defining packages, files, and commands
3. **files/** — Additional files to copy into the image
4. **README.md** — User documentation

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
mkdir -p appliances/myapp/files
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

### 3. Create config.yaml

This is the cloud-init configuration that defines how to build the image:

```yaml
# config.yaml - Incus cloud-init configuration
# This file configures the container using cloud-init

config:
  cloud-init.user-data: |
    #cloud-config
    package_update: true
    package_upgrade: false

    packages:
      # Base system
      - ca-certificates
      - curl
      - tzdata
      - logrotate
      # Networking
      - iproute2
      - iputils-ping
      # Application
      - myapp

    write_files:
      - path: /etc/myapp/config.yml
        permissions: '0644'
        content: |
          # MyApp configuration
          port: 8080
          log_level: info

      - path: /etc/motd
        permissions: '0644'
        content: |
          =====================================================
            MyApp Appliance
            Incus Appliance Registry
          =====================================================
            Config: /etc/myapp/
            Logs:   /var/log/myapp/
            Status: systemctl status myapp
          =====================================================

          Supports cloud-init for automated configuration.
          See: incus config set <instance> cloud-init.user-data ...

      - path: /etc/cloud/cloud.cfg.d/99-incus.cfg
        permissions: '0644'
        content: |
          # Incus/LXD datasource configuration
          datasource_list: [LXD]
          datasource:
            LXD:
              apply_network_config: true

    runcmd:
      # Create necessary directories
      - mkdir -p /var/lib/myapp/data
      - mkdir -p /var/log/myapp
      # Enable service at boot
      - systemctl enable myapp
      # Create user if needed
      - useradd -r -s /sbin/nologin myapp || true
      # Set permissions
      - chown -R myapp:myapp /var/lib/myapp
      - chown -R myapp:myapp /var/log/myapp
      # Disable unnecessary services for containers
      - systemctl disable apt-daily.timer || true
      - systemctl disable apt-daily-upgrade.timer || true

# Optional: Commands to run after files/ directory is copied
# Use this for setup that depends on files copied from files/
post_files: |
  # Set permissions on copied files
  chmod 755 /etc/myapp/*.sh
  chown -R myapp:myapp /etc/myapp
```

## Cloud-init Configuration

The `config.yaml` uses Incus's cloud-init configuration. The `cloud-init.user-data` field contains a standard cloud-config document.

### Key Sections

#### packages

Install packages from the distribution's repositories:

```yaml
packages:
  - nginx
  - curl
  - ca-certificates
```

#### write_files

Create files with specific content and permissions:

```yaml
write_files:
  - path: /etc/myapp/config.yaml
    permissions: '0644'
    owner: myapp:myapp
    content: |
      setting: value
```

#### runcmd

Run commands after the system boots:

```yaml
runcmd:
  - systemctl enable myapp
  - mkdir -p /var/lib/myapp
  - chown myapp:myapp /var/lib/myapp
```

#### users

Create system users:

```yaml
users:
  - name: myapp
    system: true
    shell: /sbin/nologin
    groups: [myapp]
```

### The post_files Section

The optional `post_files` section runs shell commands after the `files/` directory contents are copied into the container. Use this for:

- Setting permissions on copied files
- Running configuration scripts from files/
- Validating configuration

```yaml
post_files: |
  # Validate configuration
  myapp --validate-config /etc/myapp/config.yaml
  # Set permissions
  chmod 600 /etc/myapp/secrets.conf
```

## Using the files/ Directory

For files that are too large for inline content or are binary, place them in the `files/` directory. The directory structure mirrors the target filesystem:

```
appliances/myapp/
├── config.yaml
├── appliance.yaml
└── files/
    ├── etc/
    │   └── myapp/
    │       └── large-config.json
    └── usr/
        └── local/
            └── bin/
                └── helper-script.sh
```

These files are copied to the container after cloud-init completes, maintaining their directory structure.

## Best Practices

### Security

1. **No default passwords** — Use cloud-init or profiles to set credentials
2. **Principle of least privilege** — Run services as non-root users
3. **Minimal packages** — Only install what's needed
4. **No secrets in images** — Use external configuration

### Size Optimization

1. **Use package_upgrade: false** — Avoid upgrading all packages during build
2. **Minimal package sets** — Only install what's necessary
3. **Clean up in cloud-init** — The build process cleans package cache automatically

### Reliability

1. **Health checks** — Always include a working health check
2. **Graceful shutdown** — Handle SIGTERM properly
3. **Data persistence** — Document which directories to persist
4. **Idempotent commands** — runcmd scripts should be safe to run multiple times
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
# Or directly:
./bin/build-appliance.sh myapp
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
# appliance.yaml
volumes:
  - path: /var/lib/postgresql/data
    description: "Database files (MUST be persisted)"

healthcheck:
  command: "pg_isready -U postgres"

# config.yaml
config:
  cloud-init.user-data: |
    #cloud-config
    packages:
      - postgresql
    runcmd:
      - systemctl enable postgresql
```

### Web Service

```yaml
# appliance.yaml
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
# appliance.yaml
requirements:
  recommended_memory: 1GB

healthcheck:
  command: "redis-cli ping | grep PONG"

# config.yaml
config:
  cloud-init.user-data: |
    #cloud-config
    packages:
      - redis-server
    write_files:
      - path: /etc/redis/redis-appliance.conf
        content: |
          bind 0.0.0.0
          maxmemory 256mb
    runcmd:
      - echo "include /etc/redis/redis-appliance.conf" >> /etc/redis/redis.conf
      - systemctl enable redis-server
```

## Troubleshooting Build Issues

### Package Not Found

```yaml
# Search Debian packages at: https://packages.debian.org/

# Add backports repository if needed
runcmd:
  - echo "deb http://deb.debian.org/debian bookworm-backports main" >> /etc/apt/sources.list.d/backports.list
  - apt-get update
  - apt-get install -y mypackage/bookworm-backports
```

### Service Won't Start

```yaml
# Check service name
runcmd:
  # List available services
  - systemctl list-unit-files | grep myapp
  # Enable the correct one
  - systemctl enable myapp.service
```

### Permission Errors

```yaml
runcmd:
  # Create user first
  - useradd -r -s /sbin/nologin myapp
  # Then set ownership
  - chown -R myapp:myapp /var/lib/myapp
  # Check permissions
  - ls -la /var/lib/myapp
```

### Cloud-init Timeout

If cloud-init times out during build:
- Check for network issues (package downloads)
- Reduce the number of packages being installed
- Check for errors in cloud-init syntax

```bash
# Debug cloud-init in a running container
incus exec <container> -- cloud-init status --long
incus exec <container> -- cat /var/log/cloud-init-output.log
```

## Advanced Topics

### Multi-Architecture Builds

```bash
# Build for specific arch
make build-myapp ARCH=arm64
```

### Custom Repositories

```yaml
runcmd:
  # Add custom APT repository
  - curl -fsSL https://example.com/gpg.key | gpg --dearmor -o /usr/share/keyrings/example.gpg
  - echo "deb [signed-by=/usr/share/keyrings/example.gpg] https://example.com/apt stable main" > /etc/apt/sources.list.d/example.list
  - apt-get update
  - apt-get install -y custom-package
```

### Cloud-init for End Users

Users can further configure appliances at launch time:

```bash
incus init appliance:myapp my-instance
incus config set my-instance cloud-init.user-data - << 'EOF'
#cloud-config
write_files:
  - path: /etc/myapp/custom.conf
    content: |
      custom_setting: value
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

- [nginx](../appliances/nginx/) — Web server with cloud-init configuration
- [redis](../appliances/redis/) — In-memory cache with persistence
- [postgresql](../appliances/postgresql/) — Database server

## Getting Help

- Check existing appliances for examples
- Open an issue for questions
- Join discussions in GitHub Discussions
