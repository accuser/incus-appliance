# Atlantis Appliance

Atlantis is a Terraform/OpenTofu Pull Request automation tool for GitOps workflows. It enables you to run `terraform plan` and `apply` directly from pull request comments.

## Quick Start

```bash
# Launch the appliance
incus launch appliance:atlantis my-atlantis

# Configure credentials
incus exec my-atlantis -- nano /etc/atlantis/env

# Restart to apply configuration
incus exec my-atlantis -- systemctl restart atlantis

# Check status
incus exec my-atlantis -- systemctl status atlantis
```

## Configuration

### Required Configuration

Edit `/etc/atlantis/env` with your VCS provider credentials:

**For GitHub:**
```bash
ATLANTIS_GH_USER=your-github-user
ATLANTIS_GH_TOKEN=your-github-token
ATLANTIS_GH_WEBHOOK_SECRET=your-webhook-secret
ATLANTIS_REPO_ALLOWLIST=github.com/your-org/*
```

**For GitLab:**
```bash
ATLANTIS_GITLAB_USER=your-gitlab-user
ATLANTIS_GITLAB_TOKEN=your-gitlab-token
ATLANTIS_GITLAB_WEBHOOK_SECRET=your-webhook-secret
ATLANTIS_REPO_ALLOWLIST=gitlab.com/your-org/*
```

**For Bitbucket:**
```bash
ATLANTIS_BITBUCKET_USER=your-bitbucket-user
ATLANTIS_BITBUCKET_TOKEN=your-bitbucket-token
ATLANTIS_REPO_ALLOWLIST=bitbucket.org/your-org/*
```

### Using cloud-init

Automate configuration using cloud-init:

```yaml
#cloud-config
write_files:
  - path: /etc/atlantis/env
    permissions: '0600'
    owner: atlantis:atlantis
    content: |
      ATLANTIS_GH_USER=my-bot-user
      ATLANTIS_GH_TOKEN=ghp_xxxxxxxxxxxx
      ATLANTIS_GH_WEBHOOK_SECRET=my-webhook-secret
      ATLANTIS_REPO_ALLOWLIST=github.com/my-org/*
      ATLANTIS_PORT=4141
      ATLANTIS_DATA_DIR=/var/lib/atlantis
      ATLANTIS_REPO_CONFIG=/etc/atlantis/atlantis.yaml
      ATLANTIS_ATLANTIS_URL=https://atlantis.example.com

runcmd:
  - systemctl restart atlantis
```

Apply with:

```bash
incus launch appliance:atlantis my-atlantis --config cloud-init.user-data="$(cat cloud-config.yaml)"
```

## Setting Up Webhooks

1. Start Atlantis and note your server URL (e.g., `https://atlantis.example.com`)
2. Create a webhook in your VCS provider pointing to `https://atlantis.example.com/events`
3. Set the webhook secret to match `ATLANTIS_GH_WEBHOOK_SECRET` (or equivalent)
4. Select events: Pull Request, Push, Issue Comment

## Terraform/OpenTofu Versions

Atlantis includes a recent version of Terraform by default. To use a specific version, add to your `atlantis.yaml` in your repo:

```yaml
version: 3
projects:
  - dir: .
    terraform_version: v1.5.0
```

Or use a `.terraform-version` file in your repo root.

## Persistence

For production use, attach a storage volume for Atlantis data:

```bash
# Create a storage volume
incus storage volume create default atlantis-data

# Launch with the volume attached
incus launch appliance:atlantis my-atlantis --device data,source=atlantis-data,path=/var/lib/atlantis
```

## Reverse Proxy Setup

Atlantis should be behind a reverse proxy (like nginx) with TLS. Example nginx configuration:

```nginx
server {
    listen 443 ssl;
    server_name atlantis.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://atlantis-container:4141;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 4141 | TCP | Atlantis web UI and webhook endpoint |

## Volumes

| Path | Description |
|------|-------------|
| `/var/lib/atlantis` | Atlantis data directory |
| `/etc/atlantis` | Configuration files |

## Health Check

```bash
incus exec my-atlantis -- curl -sf http://localhost:4141/healthz
```

## Viewing Logs

```bash
incus exec my-atlantis -- journalctl -u atlantis -f
```

## Resource Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 1 core | 2+ cores |
| Memory | 512MB | 1GB+ |
| Disk | 1GB | 5GB+ |

## Tags

`gitops`, `terraform`, `opentofu`, `automation`, `ci-cd`

## Documentation

- [Atlantis Documentation](https://www.runatlantis.io/docs)
- [Server-Side Repo Config](https://www.runatlantis.io/docs/server-side-repo-config)
- [Deployment Guide](https://www.runatlantis.io/docs/deployment)
