# Base Image Updates

This document describes how base images are managed and updated in the Incus Appliance Registry.

## Overview

All appliances are built from a common base image: `images:debian/12/cloud` from [images.linuxcontainers.org](https://images.linuxcontainers.org/). This image is maintained by the Linux Containers project and is rebuilt regularly (typically daily) with the latest security patches.

## Automatic Update Detection

A scheduled GitHub Actions workflow runs weekly to check for base image updates:

1. **Check** - Compares the remote image fingerprint against a stored baseline
2. **Detect** - If the fingerprint has changed, the base image has been updated
3. **Notify** - Creates a pull request to trigger a rebuild of all appliances

### How It Works

The workflow uses the image fingerprint (SHA256 hash) to detect changes:

```bash
# Get current remote fingerprint
incus image info images:debian/12/cloud/amd64 | grep Fingerprint
```

The fingerprint is stored in `.base-image-fingerprint` in the repository. When the remote fingerprint differs from the stored value, we know the upstream image has been updated.

### Workflow Schedule

- **Frequency**: Weekly (Sunday at 2 AM UTC)
- **Trigger**: Can also be manually triggered via `workflow_dispatch`
- **Output**: Pull request if changes detected, or summary if no changes

## Manual Operations

### Check for Updates Locally

Use the included script to check if the base image has been updated:

```bash
# Check if base image has changed
./bin/check-base-image.sh

# Check and update stored fingerprint
./bin/check-base-image.sh --update
```

Exit codes:
- `0` - Base image has changed (rebuild needed)
- `1` - Base image unchanged
- `2` - Error occurred

### Force a Fresh Base Image

To ensure you're building with the absolute latest base image:

```bash
# Remove cached image (forces re-download)
incus image delete images:debian/12/cloud/amd64

# Build will now fetch the latest
./bin/build-appliance.sh nginx
```

### Force Rebuild All Appliances

Trigger a full rebuild via GitHub Actions:

1. Go to **Actions** → **Scheduled Base Image Check**
2. Click **Run workflow**
3. Check **Force rebuild even if base image unchanged**
4. Click **Run workflow**

Or trigger via CLI:

```bash
gh workflow run scheduled-rebuild.yml -f force_rebuild=true
```

## Security Monitoring

### Debian Security Resources

Monitor these resources for security updates affecting the base image:

- **[Debian Security Tracker](https://security-tracker.debian.org/tracker/)** - CVE tracking for all Debian packages
- **[Debian Security Announcements](https://www.debian.org/security/)** - Official security advisories (DSA)
- **[Debian LTS Security](https://wiki.debian.org/LTS/Security)** - Long-term support security updates

### Subscribe to Notifications

```bash
# Debian Security Announce mailing list
# https://lists.debian.org/debian-security-announce/

# RSS feed for security announcements
# https://www.debian.org/security/dsa
```

## Base Image Details

### Image Source

| Property | Value |
|----------|-------|
| Image | `images:debian/12/cloud` |
| Distribution | Debian 12 (Bookworm) |
| Variant | Cloud (includes cloud-init) |
| Source | [images.linuxcontainers.org](https://images.linuxcontainers.org/) |
| Rebuild Frequency | Daily |

### What's Included

The cloud variant includes:
- Minimal Debian 12 installation
- cloud-init for instance initialization
- systemd for service management
- Standard networking tools

### What's Updated

When the base image is rebuilt, it typically includes:
- Security patches (kernel, libraries, system packages)
- Bug fixes from Debian stable updates
- Updated CA certificates
- Any packages from `debian-security` repository

## Appliance Package Updates

Note that while the base image is updated automatically, application packages installed by appliances (nginx, postgresql, etc.) are controlled by:

1. **Debian package versions** - Packages come from Debian stable repositories
2. **Appliance version** - Specified in each `appliance.yaml`

To update application packages to newer versions, you need to:

1. Update the appliance version in `appliance.yaml`
2. Modify `config.yaml` if package names or configurations changed
3. Create a PR with the changes

## Troubleshooting

### Workflow Not Detecting Changes

If the workflow runs but doesn't detect changes when expected:

1. Verify the stored fingerprint:
   ```bash
   cat .base-image-fingerprint
   ```

2. Check the current remote fingerprint:
   ```bash
   incus image info images:debian/12/cloud/amd64 | grep Fingerprint
   ```

3. If needed, delete `.base-image-fingerprint` to reset

### Build Using Old Image

If builds are using a cached old image:

1. Delete the local cache:
   ```bash
   incus image delete images:debian/12/cloud/amd64
   ```

2. The next build will fetch the latest image

### PR Not Being Created

If the workflow detects changes but no PR appears:

1. Check if a PR already exists for base image updates
2. Verify `GITHUB_TOKEN` has write permissions
3. Check the workflow logs for errors
