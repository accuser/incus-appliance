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

# Build the nginx appliance
make build-nginx
```

This will:
1. Download Alpine Linux base image
2. Install nginx and dependencies
3. Configure the appliance
4. Add to local SimpleStreams registry

## Test Locally

```bash
# Start the local HTTPS server
make serve &

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

# Test nginx
incus exec my-nginx -- curl -s localhost
```

You should see the nginx welcome page!

## Basic Operations

### View Instance Info

```bash
incus info my-nginx
```

### Execute Commands

```bash
# Check nginx status
incus exec my-nginx -- rc-service nginx status

# View nginx version
incus exec my-nginx -- nginx -v

# Get a shell
incus exec my-nginx -- sh
```

### Manage Configuration

```bash
# Push a config file
cat > mysite.conf <<EOF
server {
    listen 80;
    server_name example.com;
    root /usr/share/nginx/html;
}
EOF

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

### Stop and Cleanup

```bash
# Stop instance
incus stop my-nginx

# Start again
incus start my-nginx

# Delete instance
incus delete my-nginx

# Delete with force (if running)
incus delete -f my-nginx
```

## Build More Appliances

```bash
# Build all appliances
make build

# Build specific appliance
make build-postgres
make build-redis

# Test an appliance
make test-nginx
```

## Create Your Own Appliance

```bash
# Create directory structure
mkdir -p appliances/myapp/{files,profiles}

# Create metadata
cat > appliances/myapp/appliance.yaml <<EOF
name: myapp
version: "1.0.0"
description: "My custom appliance"
base:
  distribution: alpine
  release: "3.20"
EOF

# Create build template
cat > appliances/myapp/image.yaml <<EOF
image:
  distribution: alpine
  release: "3.20"
  description: "My custom appliance"

source:
  downloader: alpinelinux-http
  url: https://dl-cdn.alpinelinux.org/alpine/
  keys:
    - 0482D84022F52DF1C4E7CD43293ACD0907D9495A

packages:
  manager: apk
  update: true
  cleanup: true
  sets:
    - packages: [myapp, curl]
      action: install
EOF

# Build it
make build-myapp

# Test it
incus launch appliance-test:myapp test-myapp
```

## Useful Commands

### Makefile Targets

```bash
make help              # Show all available targets
make list              # List available appliances
make validate          # Validate all templates
make build             # Build all appliances
make build-nginx       # Build specific appliance
make test              # Test all appliances
make test-nginx        # Test specific appliance
make serve             # Start local test server
make clean             # Remove build artifacts
make registry-list     # List images in registry
```

### Incus Commands

```bash
# Remotes
incus remote list
incus remote add <name> <url>
incus remote remove <name>

# Images
incus image list <remote>:
incus image delete <fingerprint>

# Instances
incus list
incus launch <image> <name>
incus start <name>
incus stop <name>
incus restart <name>
incus delete <name>
incus exec <name> -- <command>

# Files
incus file push <local> <instance>/<remote>
incus file pull <instance>/<remote> <local>

# Snapshots
incus snapshot create <instance> <snapshot-name>
incus snapshot list <instance>
incus restore <instance> <snapshot-name>

# Info
incus info <instance>
incus config show <instance>
```

## Next Steps

- Read the [full documentation](README.md)
- Learn about [creating appliances](docs/creating-appliances.md)
- Understand the [architecture](docs/architecture.md)
- Deploy to [production](docs/deployment.md)
- [Contribute](CONTRIBUTING.md) your own appliances

## Troubleshooting

### Build fails

```bash
# Check distrobuilder is installed
distrobuilder --version

# Run with sudo (required for chroot)
sudo make build-nginx

# Clear cache and retry
rm -rf .cache .build
make build-nginx
```

### Can't connect to test server

```bash
# Check server is running
ps aux | grep python3

# Regenerate certificates
rm -rf .certs
make serve

# Try different port
PORT=9443 make serve
```

### Instance won't start

```bash
# Check logs
incus info my-nginx --show-log

# Try console access
incus start my-nginx --console

# Check Incus itself
incus list
systemctl status incus
```

## Getting Help

- Check [README.md](README.md) for detailed documentation
- Search [existing issues](https://github.com/yourusername/incus-appliance/issues)
- Join discussions in [GitHub Discussions](https://github.com/yourusername/incus-appliance/discussions)
- Open a new issue with `question` label

Happy building! 🚀
