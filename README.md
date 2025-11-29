# Incus Appliance Registry

A self-hosted SimpleStreams image server for launching pre-configured Incus system container appliances with Docker-like convenience.

```bash
incus remote add appliance https://appliances.example.com --protocol simplestreams
incus launch appliance:nginx my-proxy
incus launch appliance:postgres my-db
```

## Overview

The Incus Appliance Registry provides single-purpose system containers that combine the convenience of Docker images with the operational benefits of Incus:

- **Native Integration** — Works with Incus's existing remote/image model
- **System Containers** — Full init system, SSH access, native networking
- **Unified Management** — Snapshots, live migration, resource limits
- **Reproducible Builds** — All appliances defined with distrobuilder templates
- **GitOps Ready** — Version-controlled configuration and CI/CD support

## Quick Start

### Prerequisites

- Incus (>= 6.0)
- distrobuilder
- sudo access (for building images)
- Python 3 (for local testing server)
- OpenSSL (for test certificates)

### Build an Appliance

```bash
# Clone the repository
git clone https://github.com/yourusername/incus-appliance
cd incus-appliance

# Build the nginx appliance
make build-nginx

# Or build all appliances
make build
```

### Test Locally

```bash
# Start the local test server
make serve

# In another terminal, add the test remote
incus remote add appliance-test https://localhost:8443 --protocol simplestreams --accept-certificate

# Launch an appliance
incus launch appliance-test:nginx my-nginx

# Test it
incus exec my-nginx -- curl -s localhost
```

### Validate Templates

```bash
# Validate all appliance templates
make validate

# Run integration tests
make test
```

## Available Appliances

| Name | Description | Base | Size |
|------|-------------|------|------|
| [nginx](appliances/nginx/) | Reverse proxy and web server | Alpine 3.20 | ~50MB |

More appliances coming soon: postgres, redis, traefik, caddy

## Project Structure

```
incus-appliance/
├── appliances/           # Appliance definitions
│   ├── _base/           # Shared base configurations
│   └── nginx/           # Nginx appliance
│       ├── appliance.yaml    # Metadata
│       ├── image.yaml        # Distrobuilder template
│       ├── files/            # Files to embed
│       └── README.md         # Documentation
├── scripts/             # Build and test scripts
│   ├── build-appliance.sh   # Build single appliance
│   ├── serve-local.sh       # Local test server
│   ├── validate.sh          # Validate templates
│   └── test-appliance.sh    # Test launcher
├── registry/            # Generated SimpleStreams registry (gitignored)
├── Makefile            # Build automation
└── README.md           # This file
```

## Creating Appliances

See [docs/creating-appliances.md](docs/creating-appliances.md) for a detailed guide.

### Quick Template

1. Create the appliance directory:

```bash
mkdir -p appliances/myapp/{files,profiles}
```

2. Create `appliances/myapp/appliance.yaml`:

```yaml
name: myapp
version: "1.0.0"
description: "My awesome appliance"
base:
  distribution: alpine
  release: "3.20"
```

3. Create `appliances/myapp/image.yaml`:

```yaml
image:
  distribution: alpine
  release: "3.20"
  description: "My awesome appliance"

source:
  downloader: alpinelinux-http
  url: https://dl-cdn.alpinelinux.org/alpine/

packages:
  manager: apk
  update: true
  sets:
    - packages:
        - myapp
      action: install

actions:
  - trigger: post-packages
    action: |-
      rc-update add myapp default
```

4. Build and test:

```bash
make build-myapp
make test-myapp
```

## Deployment

### Self-Hosted Registry

The registry is just static files served over HTTPS. Deploy with any web server:

#### Using Nginx

```nginx
server {
    listen 443 ssl http2;
    server_name appliances.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    root /var/www/appliances;
    autoindex off;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

#### Using Caddy

```
appliances.example.com {
    root * /var/www/appliances
    file_server
}
```

#### Sync Registry

```bash
# Rsync to web server
rsync -avz --delete registry/ user@server:/var/www/appliances/

# Or use the publish script
./scripts/publish.sh
```

### GitHub Pages / Static Hosting

The registry can be hosted on any static file hosting:

- GitHub Pages (with custom domain for HTTPS)
- Netlify
- Cloudflare Pages
- AWS S3 + CloudFront
- Any CDN

## Usage Examples

### Launch with Profiles

```bash
# Create a profile for nginx with port forwarding
cat > nginx-proxy.yaml <<EOF
config:
  security.nesting: "true"
devices:
  http:
    type: proxy
    listen: tcp:0.0.0.0:80
    connect: tcp:127.0.0.1:80
  https:
    type: proxy
    listen: tcp:0.0.0.0:443
    connect: tcp:127.0.0.1:443
EOF

incus profile create nginx-proxy
cat nginx-proxy.yaml | incus profile edit nginx-proxy

# Launch with profile
incus launch appliance:nginx my-proxy --profile default --profile nginx-proxy
```

### Persistent Configuration

```bash
# Create storage volume
incus storage volume create default nginx-config

# Launch with persistent config
incus launch appliance:nginx my-nginx
incus config device add my-nginx config disk source=nginx-config path=/etc/nginx/conf.d

# Add your configuration
incus file push mysite.conf my-nginx/etc/nginx/conf.d/
incus exec my-nginx -- nginx -s reload
```

### Backup and Restore

```bash
# Snapshot
incus snapshot create my-nginx backup-$(date +%Y%m%d)

# List snapshots
incus info my-nginx

# Restore
incus restore my-nginx backup-20250127

# Export
incus export my-nginx my-nginx-backup.tar.gz

# Import on another host
incus import my-nginx-backup.tar.gz
```

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make help` | Show all available targets |
| `make build` | Build all appliances |
| `make build-nginx` | Build specific appliance |
| `make build-all-arch` | Build for all architectures |
| `make validate` | Validate all templates |
| `make test` | Run all integration tests |
| `make test-nginx` | Test specific appliance |
| `make serve` | Start local test server |
| `make list` | List available appliances |
| `make registry-list` | List images in registry |
| `make clean` | Remove build artifacts |
| `make clean-all` | Remove build and registry |

## Architecture

### SimpleStreams Protocol

SimpleStreams is a protocol for describing and serving system images. The registry consists of:

- `streams/v1/index.json` — Entry point listing data streams
- `streams/v1/images.json` — Catalogue of images with metadata and download URLs
- `images/` — Image files (metadata tarballs and rootfs)

Incus includes `incus-simplestreams` for managing these files:

```bash
# Add an image
incus-simplestreams add <path> <metadata.tar.xz> <rootfs.squashfs> --alias <name>

# List images
incus-simplestreams list <path>

# Remove an image
incus-simplestreams remove <path> <fingerprint>
```

### Build Process

1. **Template Processing** — distrobuilder reads `image.yaml`
2. **Image Creation** — Downloads base image, installs packages, runs actions
3. **Output Generation** — Creates `incus.tar.xz` (metadata) and `rootfs.squashfs`
4. **Registry Addition** — `incus-simplestreams` adds to SimpleStreams registry
5. **Index Update** — Registry JSON files updated automatically

### Image Components

Each image consists of:

- **Metadata tarball** (`incus.tar.xz`) — Image metadata, templates
- **Root filesystem** (`rootfs.squashfs`) — Compressed root filesystem
- **Registry entries** — JSON metadata in streams/v1/images.json

## Development

### Testing Changes

```bash
# Validate templates
make validate

# Build specific appliance
make build-nginx

# Test locally
make serve &
incus remote add test https://localhost:8443 --protocol simplestreams --accept-certificate
make test-nginx
```

### Multi-Architecture Builds

```bash
# Build for specific architecture
make build-nginx ARCH=arm64

# Build all appliances for all architectures
make build-all-arch
```

### Debugging Builds

```bash
# Build with verbose output
sudo distrobuilder build-incus appliances/nginx/image.yaml --debug

# Check generated files
ls -lh .build/nginx/amd64/

# Inspect metadata
tar -tvf .build/nginx/amd64/incus.tar.xz

# Mount rootfs (requires squashfs-tools)
mkdir /tmp/rootfs
sudo mount -t squashfs .build/nginx/amd64/rootfs.squashfs /tmp/rootfs
ls -la /tmp/rootfs
sudo umount /tmp/rootfs
```

## Troubleshooting

### Build Failures

**Error: distrobuilder not found**
```bash
# Install distrobuilder
snap install distrobuilder --classic
```

**Error: Permission denied**
```bash
# distrobuilder requires sudo for chroot operations
sudo ./bin/build-appliance.sh nginx
```

**Error: Failed to download**
```bash
# Clear distrobuilder cache
rm -rf .cache/distrobuilder
```

### Registry Issues

**Error: Image not found**
```bash
# Verify registry contents
make registry-list

# Rebuild registry
make clean-all
make build
```

**Error: Certificate issues**
```bash
# Regenerate test certificates
rm -rf .certs
make serve
```

### Launch Failures

**Error: Image not in remote**
```bash
# List available images
incus image list appliance-test:

# Check remote configuration
incus remote list
```

**Error: Instance won't start**
```bash
# Check logs
incus info my-instance --show-log

# Start in foreground for debugging
incus start my-instance --console
```

## FAQ

**Q: How is this different from Docker?**

A: These are full system containers with init systems, not application containers. You get the flexibility of a VM with the efficiency of containers.

**Q: Can I use this with LXD?**

A: Yes! The templates and registry format work with both LXD and Incus. Just replace `incus` commands with `lxc`.

**Q: How do I update appliances?**

A: Rebuild the image with a new version number. Incus will fetch the latest version when launching new instances.

**Q: Can I create VM images?**

A: Yes, distrobuilder supports VM images. Change `--type=split` to `--type=unified` and configure VM-specific settings in `image.yaml`.

**Q: How do I handle secrets?**

A: Use cloud-init user-data or Incus profiles to inject secrets at launch time. Never bake secrets into images.

## Contributing

Contributions welcome! See [docs/creating-appliances.md](docs/creating-appliances.md) for guidelines.

### Adding a New Appliance

1. Fork the repository
2. Create appliance definition in `appliances/<name>/`
3. Add `appliance.yaml`, `image.yaml`, and `README.md`
4. Test: `make build-<name> && make test-<name>`
5. Submit pull request

## License

MIT License - see [LICENSE](LICENSE) for details.

## Resources

- [Incus Documentation](https://linuxcontainers.org/incus/docs/main/)
- [Distrobuilder Repository](https://github.com/lxc/distrobuilder)
- [SimpleStreams Specification](https://git.launchpad.net/simplestreams/tree/doc/README)
- [Incus Image Server](https://images.linuxcontainers.org/)

## Acknowledgments

Built with:
- [Incus](https://linuxcontainers.org/incus/) — Modern container and VM manager
- [Distrobuilder](https://github.com/lxc/distrobuilder) — Image builder for LXC/Incus
- [SimpleStreams](https://launchpad.net/simplestreams) — Image metadata protocol
