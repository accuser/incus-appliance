# Quick Start Guide

Get up and running with the Incus Appliance Registry in 5 minutes.

## Prerequisites

```bash
# Install Incus (if not already installed)
sudo snap install incus --channel=latest/stable

# Initialize Incus (if first time)
incus admin init --minimal

# Install distrobuilder
sudo snap install distrobuilder --classic
```

## Build Your First Appliance

```bash
# Clone the repository
git clone https://github.com/yourusername/incus-appliance
cd incus-appliance

# Build the nginx appliance (requires sudo for chroot)
sudo ./bin/build-appliance.sh nginx
```

This will:
1. Download Alpine Linux base image (cached for future builds)
2. Install nginx and dependencies
3. Configure the appliance
4. Add to local SimpleStreams registry

Expected output:
```
==> Building appliance: nginx (amd64)
==> Running distrobuilder...
==> Adding to SimpleStreams registry...
==> Successfully built: nginx (amd64)
    Registry: /home/user/incus-appliance/registry
```

## Test Locally

```bash
# Start the local HTTPS server
./scripts/serve-local.sh &

# Add as an Incus remote
incus remote add appliance-test https://localhost:8443 \
  --protocol simplestreams \
  --accept-certificate

# List available images
incus image list appliance-test:

# Launch an instance
incus launch appliance-test:nginx my-nginx

# Check status
incus list
```

## Verify It Works

```bash
# Get the welcome page
incus exec my-nginx -- curl -s localhost

# Check health endpoint
incus exec my-nginx -- curl -s localhost/health

# Check nginx status
incus exec my-nginx -- rc-service nginx status
```

You should see the nginx welcome page!

## Basic Operations

### Execute Commands

```bash
# View nginx version
incus exec my-nginx -- nginx -v

# Get a shell
incus exec my-nginx -- sh

# View logs
incus exec my-nginx -- tail /var/log/nginx/access.log
```

### Manage Configuration

```bash
# Push a config file
incus file push mysite.conf my-nginx/etc/nginx/conf.d/

# Reload nginx
incus exec my-nginx -- nginx -s reload
```

### Networking

```bash
# Get instance IP
incus list my-nginx

# Forward port 8080 to container's port 80
incus config device add my-nginx myport8080 proxy \
  listen=tcp:0.0.0.0:8080 \
  connect=tcp:127.0.0.1:80

# Now access via http://localhost:8080
curl http://localhost:8080
```

### Snapshots

```bash
# Create snapshot
incus snapshot create my-nginx backup1

# List snapshots
incus info my-nginx

# Restore snapshot
incus restore my-nginx backup1
```

### Cleanup

```bash
# Stop instance
incus stop my-nginx

# Delete instance
incus delete my-nginx

# Delete with force (if running)
incus delete -f my-nginx

# Remove test remote (optional)
incus remote remove appliance-test
```

## Using Make (Recommended)

If you have `make` installed:

```bash
make build-nginx      # Build nginx appliance
make serve            # Start test server
make test-nginx       # Test appliance
make validate         # Validate templates
make help             # Show all targets
```

## What's Created

```
registry/                        # Generated SimpleStreams registry
├── streams/v1/
│   ├── index.json              # Entry point
│   └── images.json             # Image catalog
└── images/<fingerprint>/
    ├── incus.tar.xz            # Image metadata
    └── rootfs.squashfs         # Root filesystem

.build/nginx/amd64/             # Build artifacts
.cache/distrobuilder/           # Downloaded base images (reused)
.certs/                         # Test SSL certificates
```

## Troubleshooting

### Build fails

```bash
# Check distrobuilder is installed
distrobuilder --version

# Run with sudo (required for chroot)
sudo ./bin/build-appliance.sh nginx

# Clear cache and retry
rm -rf .cache .build
sudo ./bin/build-appliance.sh nginx
```

### Can't connect to test server

```bash
# Check server is running
ps aux | grep python3

# Regenerate certificates
rm -rf .certs
./scripts/serve-local.sh
```

### Instance won't start

```bash
# Check logs
incus info my-nginx --show-log

# Try console access
incus start my-nginx --console
```

## Next Steps

- Read the full [README](README.md)
- Learn about [creating appliances](docs/creating-appliances.md)
- Understand the [architecture](docs/architecture.md)
- Deploy to [production](docs/deployment.md)
- [Contribute](CONTRIBUTING.md) your own appliances

Happy building!
