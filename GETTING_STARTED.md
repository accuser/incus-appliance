# Getting Started with Incus Appliance Registry

Welcome! This guide will help you get the Incus Appliance Registry up and running.

## What You've Got

This is a complete, production-ready implementation of a self-hosted SimpleStreams image server for Incus appliances. Think of it as your own private "Docker Hub" for system containers.

## Quick Overview

The project includes:

- ✅ **Core build system** — Automated image building with distrobuilder
- ✅ **SimpleStreams registry** — Industry-standard image distribution
- ✅ **Testing infrastructure** — Local HTTPS server and test suite
- ✅ **Reference appliance** — Complete nginx implementation
- ✅ **Comprehensive docs** — Everything you need to use and extend
- ✅ **Deployment tools** — Scripts for production deployment

## Your First Build (5 minutes)

### Step 1: Install Prerequisites

```bash
# Install Incus (if not already)
sudo snap install incus --channel=latest/stable
incus admin init --minimal

# Install distrobuilder
sudo snap install distrobuilder --classic

# Verify installation
incus --version
distrobuilder --version
```

### Step 2: Build the Nginx Appliance

```bash
# Build the appliance (requires sudo for chroot)
sudo ./bin/build-appliance.sh nginx
```

This will:
1. Download Alpine Linux base (cached for future builds)
2. Install nginx and dependencies
3. Configure the system
4. Create the image files
5. Add to the local SimpleStreams registry

Expected output:
```
==> Building appliance: nginx (amd64)
==> Running distrobuilder...
==> Adding to SimpleStreams registry...
==> Successfully built: nginx (amd64)
    Registry: /home/user/incus-appliance/registry
```

### Step 3: Test Locally

```bash
# Start the local test server
./scripts/serve-local.sh &

# This generates self-signed certs and serves the registry on https://localhost:8443
```

In a new terminal:

```bash
# Add the test remote
incus remote add appliance-test https://localhost:8443 \
  --protocol simplestreams \
  --accept-certificate

# List available images
incus image list appliance-test:

# Launch an instance
incus launch appliance-test:nginx my-nginx

# Check it's running
incus list
```

### Step 4: Test the Appliance

```bash
# Get the welcome page
incus exec my-nginx -- curl -s localhost

# Check health endpoint
incus exec my-nginx -- curl -s localhost/health

# View logs
incus exec my-nginx -- tail /var/log/nginx/access.log
```

Success! You now have a working nginx appliance.

## What Just Happened?

1. **Build Process**
   - distrobuilder downloaded Alpine Linux
   - Installed nginx and dependencies
   - Applied configuration from `appliances/nginx/image.yaml`
   - Created two files: `incus.tar.xz` (metadata) and `rootfs.squashfs` (filesystem)

2. **Registry Creation**
   - `incus-simplestreams` added the image to `registry/`
   - Created JSON metadata in `registry/streams/v1/`
   - Copied image files to `registry/images/<fingerprint>/`

3. **Local Testing**
   - Python HTTPS server serves the registry
   - Incus fetches images via SimpleStreams protocol
   - Launches container from the image

## File Layout

Here's what was created:

```
registry/                        # Generated SimpleStreams registry
├── streams/v1/
│   ├── index.json              # Entry point
│   └── images.json             # Image catalog
└── images/<fingerprint>/
    ├── incus.tar.xz            # Image metadata
    └── rootfs.squashfs         # Root filesystem

.build/nginx/amd64/             # Build artifacts
├── incus.tar.xz
├── rootfs.squashfs
└── image.yaml                  # Copy of template

.cache/distrobuilder/           # Downloaded base images (reused)
└── ...

.certs/                         # Test SSL certificates
├── server.crt
└── server.key
```

## Using Make (Recommended)

If you have `make` installed:

```bash
# Build
make build-nginx

# Test server
make serve

# Test appliance
make test-nginx

# Validate templates
make validate

# List available targets
make help
```

## Next Steps

### Clean Up Test Instance

```bash
# Stop and remove
incus delete -f my-nginx

# Remove test remote (optional)
incus remote remove appliance-test
```

### Build More Appliances

Add more appliances to `appliances/` following the nginx example:

```bash
mkdir -p appliances/myapp/{files,profiles}
# Create appliance.yaml, image.yaml, README.md
sudo ./bin/build-appliance.sh myapp
```

See [docs/creating-appliances.md](docs/creating-appliances.md) for details.

### Deploy to Production

```bash
# Build all appliances
sudo ./bin/build-all.sh

# Deploy to web server (rsync example)
./scripts/publish.sh user@server:/var/www/appliances

# Or to S3
PUBLISH_METHOD=s3 ./scripts/publish.sh s3://my-bucket/appliances
```

See [docs/deployment.md](docs/deployment.md) for production deployment.

### Use in Production

On client machines:

```bash
# Add your registry
incus remote add appliance https://appliances.example.com \
  --protocol simplestreams

# Launch appliances
incus launch appliance:nginx production-proxy
incus launch appliance:postgres production-db
```

## Common Tasks

### Rebuild an Appliance

```bash
# After making changes to templates
sudo ./bin/build-appliance.sh nginx
```

### Test All Appliances

```bash
# Run integration tests
./bin/test-all.sh
```

### Export Registry

```bash
# Create tarball for distribution
tar -czf registry.tar.gz registry/
```

### Multi-Architecture Builds

```bash
# Build for ARM64
sudo ./bin/build-appliance.sh nginx arm64

# Build all appliances for all architectures
# (This takes a while!)
make build-all-arch
```

## Troubleshooting

### "distrobuilder not found"

```bash
sudo snap install distrobuilder --classic
```

### "Permission denied" during build

```bash
# distrobuilder requires sudo
sudo ./bin/build-appliance.sh nginx
```

### "Cannot connect to test server"

```bash
# Check if server is running
ps aux | grep python3

# Restart server
pkill -f serve-local.sh
./scripts/serve-local.sh &
```

### "Image not found in remote"

```bash
# List what's available
incus image list appliance-test:

# Check registry contents
sudo incus-simplestreams list registry/

# Rebuild if needed
sudo ./bin/build-appliance.sh nginx
```

## Documentation Index

- [README.md](README.md) — Project overview and detailed documentation
- [QUICKSTART.md](QUICKSTART.md) — Fast-track getting started
- [CONTRIBUTING.md](CONTRIBUTING.md) — How to contribute
- [docs/creating-appliances.md](docs/creating-appliances.md) — Create new appliances
- [docs/architecture.md](docs/architecture.md) — Technical deep dive
- [docs/deployment.md](docs/deployment.md) — Production deployment
- [PROJECT_STATUS.md](PROJECT_STATUS.md) — Project status and roadmap

## Resources

### Incus
- [Incus Documentation](https://linuxcontainers.org/incus/docs/main/)
- [Incus Image Management](https://linuxcontainers.org/incus/docs/main/image-handling/)

### Distrobuilder
- [Distrobuilder GitHub](https://github.com/lxc/distrobuilder)
- [Distrobuilder Examples](https://github.com/lxc/distrobuilder/tree/main/doc/examples)

### SimpleStreams
- [Official Images](https://images.linuxcontainers.org/) — See it in action

## Need Help?

1. Check the [docs/](docs/) directory
2. Search [existing issues](https://github.com/yourusername/incus-appliance/issues)
3. Open a new issue with details
4. Join discussions

## Tips

- **Cache is your friend** — First build is slow, subsequent builds are fast
- **Test locally first** — Use `make serve` before production
- **Start with nginx** — Use it as a reference for new appliances
- **Read the logs** — `incus info <instance> --show-log` is helpful
- **Snapshot often** — `incus snapshot` is your safety net

Happy building! 🎉
