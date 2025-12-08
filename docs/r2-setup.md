# Cloudflare R2 Setup Guide

This guide explains how to migrate the appliance registry from GitHub Pages to Cloudflare R2.

## Why R2?

| Feature | GitHub Pages | Cloudflare R2 |
|---------|-------------|---------------|
| Storage | 1 GB limit | 10 GB free |
| Bandwidth | 100 GB/month | **Unlimited free** |
| Cost | Free | Free (for our usage) |
| CDN | GitHub's CDN | Cloudflare's global CDN |

R2's free egress eliminates bandwidth concerns as the registry grows.

## Prerequisites

- Cloudflare account (free tier works)
- Access to repository settings (to add secrets)

## Setup Steps

### 1. Create R2 Bucket

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Go to **R2 Object Storage** in the sidebar
3. Click **Create bucket**
4. Name it `incus-appliance` (or your preferred name)
5. Select a location hint (optional)
6. Click **Create bucket**

### 2. Enable Public Access

1. Go to your bucket's **Settings**
2. Under **Public access**, click **Allow Access**
3. Choose one of:
   - **R2.dev subdomain**: Get a `*.r2.dev` URL (quick setup)
   - **Custom domain**: Use your own domain like `appliances.example.com`

#### Custom Domain Setup

1. Add your domain to Cloudflare (if not already)
2. In bucket settings, click **Connect Domain**
3. Enter your subdomain (e.g., `appliances.example.com`)
4. Cloudflare automatically configures DNS

### 3. Create API Token

1. Go to **R2 Object Storage** → **Manage R2 API Tokens**
2. Click **Create API Token**
3. Configure:
   - **Token name**: `github-actions-registry`
   - **Permissions**: Object Read & Write
   - **Specify bucket**: Select your bucket
4. Click **Create API Token**
5. Copy the **Access Key ID** and **Secret Access Key**

### 4. Configure GitHub Repository

Add these secrets in **Settings** → **Secrets and variables** → **Actions**:

| Secret | Value |
|--------|-------|
| `R2_ACCOUNT_ID` | Your Cloudflare Account ID (from dashboard URL) |
| `R2_ACCESS_KEY_ID` | The Access Key ID from step 3 |
| `R2_SECRET_ACCESS_KEY` | The Secret Access Key from step 3 |

Add this variable in **Settings** → **Secrets and variables** → **Actions** → **Variables**:

| Variable | Value |
|----------|-------|
| `R2_ENABLED` | `true` |
| `R2_BUCKET` | `incus-appliance` (or your bucket name) |

### 5. Configure Cache Rules (Recommended)

In Cloudflare Dashboard:

1. Go to **Rules** → **Cache Rules**
2. Create a rule for your R2 domain:

**Rule 1: Long cache for images**
- If: URI Path contains `/images/`
- Then: Cache TTL = 1 year, Browser TTL = 1 year

**Rule 2: Short cache for metadata**
- If: URI Path contains `/streams/`
- Then: Cache TTL = 5 minutes, Browser TTL = 5 minutes

### 6. Test the Setup

Trigger a workflow run:

```bash
gh workflow run "Build and Publish Registry" --ref main -f force_rebuild=true
```

Check that `publish-r2` job runs successfully.

### 7. Update Documentation

Once R2 is working, update the registry URL in:
- README.md
- Any user documentation

```bash
# New remote URL
incus remote add appliance https://appliances.example.com --protocol simplestreams
```

## Migration Strategy

When R2 is enabled, the workflow publishes the **full registry to R2** and a **landing page to GitHub Pages** that points users to R2. This allows:

1. **Gradual migration**: Test R2 while keeping a presence on GitHub Pages
2. **Zero downtime**: The landing page provides instructions for the new registry URL
3. **Simple rollback**: Disable R2 to restore full GitHub Pages publishing

## Cost Estimation

With 15 appliances × 2 architectures × ~100 MB average:

| Resource | Usage | Cost |
|----------|-------|------|
| Storage | ~3 GB | Free (10 GB included) |
| Class A (writes) | ~30/month | Free (1M included) |
| Class B (reads) | ~1000/month | Free (10M included) |
| Egress | Any amount | **Always free** |

R2 should remain in the free tier indefinitely for this use case.

## Disabling R2

To disable R2 publishing:

1. Set `R2_ENABLED` variable to `false` (or delete it)
2. The `publish-r2` job will be skipped
3. The full registry will be published to GitHub Pages instead

## Troubleshooting

### "Bucket not found" error

- Verify `R2_BUCKET` variable matches your bucket name
- Check that API token has access to the correct bucket

### "Access denied" error

- Verify API token has Read & Write permissions
- Check that Account ID is correct

### Images not loading

- Ensure public access is enabled on the bucket
- Check CORS settings if accessing from a browser

### Cache not updating

- Metadata files have 5-minute cache TTL
- Wait or purge cache in Cloudflare Dashboard

## Cache Rules Configuration

For optimal performance, configure these cache rules in Cloudflare:

```
# Images are immutable (by fingerprint)
/images/*  →  Cache-Control: public, max-age=31536000, immutable

# Metadata changes with each build
/streams/* →  Cache-Control: public, max-age=300

# HTML pages
/*.html    →  Cache-Control: public, max-age=300
```

These are set automatically by the sync script, but you can override them with Cloudflare Cache Rules for more control.
