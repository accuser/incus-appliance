# Creating Appliances

This guide walks you through creating a new appliance for the Incus Appliance Registry.

## Overview

An appliance consists of:

1. **appliance.yaml** — Metadata about the appliance (optional but recommended)
2. **image.yaml** — Distrobuilder template defining the image build process
3. **files/** — Files to embed in the image
4. **README.md** — User documentation
5. **profiles/** — Optional Incus profiles (optional)

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
  distribution: alpine  # or debian, ubuntu, etc.
  release: "3.20"

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
  distribution: alpine
  release: "3.20"
  description: "MyApp appliance"
  architecture: amd64

source:
  downloader: alpinelinux-http
  url: https://dl-cdn.alpinelinux.org/alpine/
  keys:
    - 0482D84022F52DF1C4E7CD43293ACD0907D9495A

targets:
  incus:
    vm:
      filesystem: ext4
      size: 1GiB

packages:
  manager: apk
  update: true
  cleanup: true
  sets:
    - packages:
        - myapp
        - ca-certificates
        - curl
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
      rc-update add myapp default

      # Create user
      adduser -D -H -s /sbin/nologin myapp

  - trigger: post-files
    action: |-
      # Set permissions
      chown -R myapp:myapp /var/lib/myapp
      chown -R myapp:myapp /var/log/myapp
      chmod 755 /etc/myapp
```

## Distribution-Specific Examples

### Alpine Linux

Best for: Small, simple applications

```yaml
image:
  distribution: alpine
  release: "3.20"

source:
  downloader: alpinelinux-http
  url: https://dl-cdn.alpinelinux.org/alpine/
  keys:
    - 0482D84022F52DF1C4E7CD43293ACD0907D9495A

packages:
  manager: apk
  update: true
  cleanup: true
```

**Pros**: Minimal size, fast builds, simple init (OpenRC)
**Cons**: musl libc (some software incompatible)

### Debian

Best for: Complex applications, compatibility

```yaml
image:
  distribution: debian
  release: bookworm
  variant: minbase

source:
  downloader: debootstrap
  url: http://deb.debian.org/debian

packages:
  manager: apt
  update: true
  cleanup: true
```

**Pros**: Wide compatibility, glibc, extensive packages
**Cons**: Larger size, systemd complexity

### Ubuntu

Best for: Popular software with PPAs

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

**Pros**: PPAs, commercial support, familiar
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
      systemctl enable myapp  # for systemd
      rc-update add myapp default  # for OpenRC

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

1. **Use Alpine** — When possible, Alpine images are 5-10x smaller
2. **Clean package cache** — Enable `cleanup: true`
3. **Remove unnecessary packages** — Minimal package sets
4. **Multi-stage builds** — Build dependencies in separate container
5. **Compress static content** — Pre-compress large files

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
incus exec test-instance -- dmesg
incus exec test-instance -- cat /var/log/myapp/error.log

# Test service
incus exec test-instance -- rc-service myapp status

# Test health check
incus exec test-instance -- curl -s localhost:8080/health

# Test configuration
incus exec test-instance -- cat /etc/myapp/config.yml

# Interactive shell
incus exec test-instance -- sh
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
# For Alpine, search packages:
# https://pkgs.alpinelinux.org/packages

# Add community repository if needed
actions:
  - trigger: post-unpack
    action: |-
      echo "http://dl-cdn.alpinelinux.org/alpine/v3.20/community" >> /etc/apk/repositories
```

### Service Won't Start

```yaml
# Check service name
actions:
  - trigger: post-packages
    action: |-
      # List available services
      ls -la /etc/init.d/
      # Enable the correct one
      rc-update add myserviced default
```

### Permission Errors

```yaml
actions:
  - trigger: post-files
    action: |-
      # Create user first
      adduser -D -H -s /sbin/nologin myapp
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
# Alpine edge packages
actions:
  - trigger: post-unpack
    action: |-
      echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
      apk update
```

### Cloud-init Integration

```yaml
# Include cloud-init
packages:
  sets:
    - packages:
        - cloud-init
      action: install

# Configure cloud-init
files:
  - path: /etc/cloud/cloud.cfg.d/99-custom.cfg
    generator: dump
    content: |-
      datasource_list: [NoCloud, None]
      disable_root: false
```

## Contributing Guidelines

When submitting a new appliance:

1. **Test thoroughly** — Build and launch successfully
2. **Document well** — Complete README.md with examples
3. **Follow conventions** — Use existing appliances as templates
4. **Health checks** — Always include working health check
5. **Security review** — No passwords, minimal attack surface
6. **Size conscious** — Use Alpine when possible
7. **Metadata complete** — Fill out appliance.yaml completely

## Example Appliances

Study these reference implementations:

- [nginx](../appliances/nginx/) — Minimal, well-documented
- More examples coming soon

## Getting Help

- Check existing appliances for examples
- Open an issue for questions
- Join discussions in GitHub Discussions
