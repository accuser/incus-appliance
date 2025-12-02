# Quick Start Guide

Get up and running with the Incus Appliance Registry in 5 minutes.

## Prerequisites

```bash
# Install Incus (if not already installed)
sudo apt install incus
# Or via snap
sudo snap install incus --channel=latest/stable

# Initialize Incus (if first time)
incus admin init --minimal

# Install incus-simplestreams for registry management
sudo apt install incus-simplestreams
# Or via snap
sudo snap install incus-simplestreams --classic
```

## Build Your First Appliance

```bash
# Clone the repository
git clone https://github.com/yourusername/incus-appliance
cd incus-appliance

# Build the nginx appliance
./bin/build-appliance.sh nginx
```

This will:
1. Launch a container from `images:debian/12/cloud`
2. Apply cloud-init configuration (install nginx, configure services)
3. Export as a reusable image
4. Add to local SimpleStreams registry

Expected output:
```
==> Building appliance: nginx v1.0.0 (amd64)
==> Creating build container from images:debian/12/cloud...
==> Applying cloud-init configuration...
==> Starting container...
==> Waiting for cloud-init to complete...
==> cloud-init completed
==> Publishing container as image...
==> Adding to SimpleStreams registry...
==> Successfully built: nginx v1.0.0 (amd64)
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
incus exec my-nginx -- systemctl status nginx
```

You should see the nginx welcome page!

## Basic Operations

### Execute Commands

```bash
# View nginx version
incus exec my-nginx -- nginx -v

# Get a shell
incus exec my-nginx -- bash

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
.certs/                         # Test SSL certificates
```

## Troubleshooting

### Build fails

```bash
# Check Incus is running
incus info

# Check user has permissions (should be in incus group)
groups

# Check cloud-init logs if timeout
incus exec <container> -- cat /var/log/cloud-init-output.log
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
