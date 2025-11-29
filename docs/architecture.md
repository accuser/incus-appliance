# Architecture

This document describes the technical architecture of the Incus Appliance Registry.

## Overview

The registry implements the SimpleStreams protocol to serve Incus-compatible system container images over HTTPS. It consists of:

1. **Build System** — Creates reproducible images from declarative templates
2. **Registry** — Static file structure serving image metadata and downloads
3. **Test Infrastructure** — Local development and validation tools

## Components

### 1. Build System

```
┌─────────────────┐
│ appliance.yaml  │  Metadata
│ image.yaml      │  Build template
│ files/          │  Embedded files
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ distrobuilder   │  Image builder
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ incus.tar.xz    │  Metadata tarball
│ rootfs.squashfs │  Root filesystem
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ incus-          │  Registry manager
│ simplestreams   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ registry/       │  SimpleStreams tree
│ ├── streams/    │
│ └── images/     │
└─────────────────┘
```

#### distrobuilder

Distrobuilder is the official image builder for LXC/Incus. It:

- Downloads base distribution images
- Installs packages
- Injects files
- Runs post-processing actions
- Outputs split images (metadata + rootfs)

Template format:

```yaml
image:          # Image metadata
source:         # Where to get base image
packages:       # Packages to install
files:          # Files to inject
actions:        # Scripts to run
```

#### incus-simplestreams

Manages the SimpleStreams registry structure:

```bash
incus-simplestreams add <path> <metadata> <rootfs> --alias <name>
```

This command:
1. Calculates image fingerprint (SHA256)
2. Copies files to `images/<fingerprint>/`
3. Updates `streams/v1/images.json`
4. Updates `streams/v1/index.json`

### 2. SimpleStreams Registry

#### Directory Structure

```
registry/
├── streams/
│   └── v1/
│       ├── index.json         # Stream index
│       └── images.json        # Image catalog
└── images/
    └── <fingerprint>/
        ├── incus.tar.xz       # Metadata
        └── rootfs.squashfs    # Filesystem
```

#### index.json

Entry point listing available data streams:

```json
{
  "index": {
    "images": {
      "datatype": "image-downloads",
      "path": "streams/v1/images.json",
      "format": "products:1.0"
    }
  }
}
```

#### images.json

Complete catalog of images:

```json
{
  "products": {
    "nginx": {
      "aliases": "nginx,nginx/amd64",
      "arch": "amd64",
      "os": "alpine",
      "release": "3.20",
      "versions": {
        "20250127": {
          "items": {
            "incus.tar.xz": {
              "ftype": "incus.tar.xz",
              "path": "images/<fingerprint>/incus.tar.xz",
              "sha256": "..."
            },
            "rootfs.squashfs": {
              "ftype": "squashfs",
              "path": "images/<fingerprint>/rootfs.squashfs",
              "sha256": "..."
            }
          }
        }
      }
    }
  }
}
```

### 3. Client Integration

#### How Incus Uses the Registry

```
┌──────────┐                  ┌──────────┐
│  User    │                  │  Registry│
└────┬─────┘                  └────┬─────┘
     │                             │
     │ incus launch appliance:nginx│
     ├────────────────────────────►│
     │                             │
     │ GET /streams/v1/index.json  │
     │◄────────────────────────────┤
     │                             │
     │ GET /streams/v1/images.json │
     │◄────────────────────────────┤
     │                             │
     │ GET /images/.../incus.tar.xz│
     │◄────────────────────────────┤
     │                             │
     │ GET .../rootfs.squashfs     │
     │◄────────────────────────────┤
     │                             │
     │ Launch container            │
     └─────────────────────────────┘
```

Steps:

1. **Fetch index** — Read `streams/v1/index.json`
2. **Fetch catalog** — Read `streams/v1/images.json`
3. **Find image** — Match alias to fingerprint
4. **Download files** — Fetch metadata and rootfs
5. **Import** — Add to local image store
6. **Launch** — Create container from image

### 4. Build Process

#### Single Appliance Build

```bash
make build-nginx
```

Flow:

1. **Validation** — Check for required files
2. **Prepare** — Copy template and files to `.build/`
3. **Build** — Run distrobuilder
4. **Register** — Add to SimpleStreams registry

Script: [bin/build-appliance.sh](../bin/build-appliance.sh)

#### Multi-Architecture Build

```bash
make build-all-arch
```

For each architecture:
- Set `image.architecture` parameter
- Build with arch-specific base image
- Add to registry with arch-specific alias

Example aliases:
- `nginx` (default architecture)
- `nginx/amd64`
- `nginx/arm64`

### 5. Testing Infrastructure

#### Local Test Server

```bash
make serve
```

Components:

1. **Certificate Generation** — Self-signed cert for HTTPS
2. **HTTPS Server** — Python's http.server with SSL
3. **Registry Serving** — Serves `registry/` directory

Port: 8443 (configurable via `PORT` env var)

#### Test Workflow

```bash
# Build image
make build-nginx

# Start server
make serve &

# Add remote
incus remote add test https://localhost:8443 \
  --protocol simplestreams \
  --accept-certificate

# Launch
incus launch test:nginx my-nginx

# Test
make test-nginx
```

## Data Flow

### Image Build Flow

```
Template (YAML)
    ↓
distrobuilder
    ↓
Base Image Download
    ↓
Package Installation
    ↓
File Injection
    ↓
Action Execution
    ↓
Image Generation (tar.xz + squashfs)
    ↓
Registry Addition
    ↓
JSON Metadata Update
```

### Launch Flow

```
User Command
    ↓
Remote Fetch (index.json)
    ↓
Image Lookup (images.json)
    ↓
File Download (metadata + rootfs)
    ↓
Local Import
    ↓
Container Creation
    ↓
Cloud-init (if configured)
    ↓
Service Startup
```

## File Formats

### incus.tar.xz (Metadata Tarball)

Contains:

```
metadata.yaml       # Image metadata
templates/          # Cloud-init templates
```

Example metadata.yaml:

```yaml
architecture: amd64
creation_date: 1706380800
properties:
  description: "Nginx reverse proxy appliance"
  os: alpine
  release: "3.20"
templates: {}
```

### rootfs.squashfs

Compressed read-only filesystem containing:
- Complete Linux root filesystem
- Installed packages
- Injected files
- Configured services

Format: SquashFS (highly compressed)

### Registry JSON

Generated and managed by `incus-simplestreams`:

- **index.json** — Stream catalog
- **images.json** — Image metadata, fingerprints, file paths

## Security Considerations

### Image Security

1. **Build Process**
   - Runs as root (required for chroot)
   - Isolated build environment
   - Reproducible from templates

2. **Distribution**
   - HTTPS required for registry
   - SHA256 fingerprints for integrity
   - Client verifies checksums

3. **Runtime**
   - No default passwords
   - Minimal attack surface
   - Services run as non-root users

### Registry Security

1. **Transport**
   - HTTPS mandatory
   - Certificate validation
   - Secure by default

2. **Content**
   - Static files only
   - No code execution on server
   - Read-only serving

## Performance

### Build Performance

- **Cache** — distrobuilder caches base images in `.cache/`
- **Parallel** — Multiple appliances can build concurrently
- **Incremental** — Only rebuild changed appliances

### Registry Performance

- **Static** — No database, no dynamic generation
- **Cacheable** — All content is cacheable
- **CDN-friendly** — Can be served from CDN
- **Small metadata** — JSON files are small (<1MB typically)

### Image Size

Typical sizes:

- **Alpine-based**: 20-100MB
- **Debian-based**: 100-500MB
- **Ubuntu-based**: 200-800MB

Compression ratios (SquashFS): ~3-5x

## Scalability

### Registry Scalability

Static files scale horizontally:

- **CDN** — CloudFront, Cloudflare, Fastly
- **Object Storage** — S3, GCS, B2
- **Replication** — rsync, s3 sync
- **Caching** — Varnish, nginx caching

### Build Scalability

- **Distributed** — Build on multiple machines
- **CI/CD** — GitHub Actions, GitLab CI
- **Scheduled** — Cron for regular rebuilds
- **On-demand** — Trigger via webhooks

## Extensibility

### Custom Distributions

Add new base distributions by creating source configs:

```yaml
source:
  downloader: custom-http
  url: https://custom-distro.org/releases/
```

### Custom Metadata

Extend appliance.yaml with custom fields:

```yaml
custom:
  monitoring:
    prometheus: true
    metrics_port: 9090
```

### Profiles

Bundle Incus profiles with appliances:

```yaml
appliances/nginx/profiles/nginx-proxy.yaml
```

Users can apply with:

```bash
incus launch appliance:nginx my-nginx --profile nginx-proxy
```

## Comparison to Alternatives

### vs Docker Hub

| Feature | Appliance Registry | Docker Hub |
|---------|-------------------|------------|
| Type | System containers | App containers |
| Init | Full (OpenRC/systemd) | Single process |
| Images | Stateful | Stateless |
| Networking | Native | Bridge/NAT |
| Hosting | Self-hosted | Centralized |

### vs images.linuxcontainers.org

| Feature | Appliance Registry | images.l.o |
|---------|-------------------|------------|
| Purpose | Pre-configured apps | Base distros |
| Scope | Single-purpose | General-purpose |
| Customization | Application-specific | Minimal |
| Hosting | Self-hosted | Canonical/LXC |

## Future Enhancements

### Planned Features

1. **VM Support** — Add VM image builds
2. **Versioning** — Semantic versioning for appliances
3. **Dependencies** — Express appliance dependencies
4. **Profiles** — Bundled Incus profiles
5. **Cloud-init** — Enhanced cloud-init support

### Potential Integrations

1. **Terraform** — Incus provider
2. **Ansible** — Incus modules
3. **Monitoring** — Prometheus exporters
4. **Logging** — Structured logging
5. **Secrets** — Vault integration

## References

- [SimpleStreams Specification](https://git.launchpad.net/simplestreams/tree/doc/README)
- [Incus Image Format](https://linuxcontainers.org/incus/docs/main/image-handling/)
- [Distrobuilder Documentation](https://distrobuilder.readthedocs.io/)
- [SquashFS Documentation](https://www.kernel.org/doc/Documentation/filesystems/squashfs.txt)
