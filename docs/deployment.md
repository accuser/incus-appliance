# Deployment Guide

This guide covers deploying the Incus Appliance Registry to production.

## Overview

The registry consists of static files that can be served from any HTTPS-enabled web server or CDN. No dynamic processing or database is required.

## Deployment Options

### Option 1: Traditional Web Server

Best for: Self-hosted, full control, existing infrastructure

Supported servers:
- Nginx
- Apache
- Caddy
- Lighttpd

### Option 2: Object Storage + CDN

Best for: High availability, global distribution, low maintenance

Supported services:
- AWS S3 + CloudFront
- Google Cloud Storage + Cloud CDN
- Azure Blob Storage + CDN
- Cloudflare R2 + CDN
- Backblaze B2 + Cloudflare

### Option 3: Static Hosting

Best for: Simple setup, low cost, Git-based workflow

Supported platforms:
- GitHub Pages (with custom domain)
- Netlify
- Cloudflare Pages
- Vercel

## Prerequisites

All options require:

1. **HTTPS** — SimpleStreams protocol requires HTTPS
2. **Custom Domain** (optional) — For branded URLs
3. **Built Registry** — Run `make build` to generate registry files

## Deployment: Nginx

### 1. Install Nginx

```bash
# Debian/Ubuntu
sudo apt install nginx

# Alpine
sudo apk add nginx

# RHEL/CentOS
sudo dnf install nginx
```

### 2. Configure Virtual Host

Create `/etc/nginx/sites-available/appliances.conf`:

```nginx
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name appliances.example.com;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/appliances.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/appliances.example.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Registry root
    root /var/www/appliances;

    # Disable autoindex for security
    autoindex off;

    # Security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";

    # Enable CORS for SimpleStreams
    add_header Access-Control-Allow-Origin *;
    add_header Access-Control-Allow-Methods "GET, HEAD, OPTIONS";
    add_header Access-Control-Allow-Headers "Content-Type";

    # Cache control
    location /streams/ {
        expires 5m;
        add_header Cache-Control "public, must-revalidate";
    }

    location /images/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Main location
    location / {
        try_files $uri $uri/ =404;
    }

    # Logging
    access_log /var/log/nginx/appliances-access.log;
    error_log /var/log/nginx/appliances-error.log;
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name appliances.example.com;
    return 301 https://$server_name$request_uri;
}
```

### 3. Enable Site

```bash
# Enable configuration
sudo ln -s /etc/nginx/sites-available/appliances.conf /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

### 4. Deploy Registry

```bash
# Create web root
sudo mkdir -p /var/www/appliances

# Copy registry files
sudo rsync -av registry/ /var/www/appliances/

# Set permissions
sudo chown -R www-data:www-data /var/www/appliances
sudo chmod -R 755 /var/www/appliances
```

### 5. Automated Deployment

Create `scripts/publish-custom.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

REGISTRY_DIR="$1"
REMOTE_SERVER="user@appliances.example.com"
REMOTE_PATH="/var/www/appliances"

rsync -avz --delete \
  --rsync-path="sudo rsync" \
  "${REGISTRY_DIR}/" \
  "${REMOTE_SERVER}:${REMOTE_PATH}/"

ssh "${REMOTE_SERVER}" "sudo chown -R www-data:www-data ${REMOTE_PATH}"
```

Then:

```bash
chmod +x scripts/publish-custom.sh
PUBLISH_METHOD=custom PUBLISH_DEST=unused ./scripts/publish.sh
```

## Deployment: Caddy

### 1. Install Caddy

```bash
# Debian/Ubuntu
sudo apt install caddy

# Or from official source
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/setup.deb.sh' | sudo bash
sudo apt install caddy
```

### 2. Configure Caddyfile

Create `/etc/caddy/Caddyfile`:

```
appliances.example.com {
    root * /var/www/appliances
    file_server

    # Security headers
    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        X-XSS-Protection "1; mode=block"
        Access-Control-Allow-Origin *
    }

    # Cache control
    @streams path /streams/*
    header @streams Cache-Control "public, max-age=300"

    @images path /images/*
    header @images Cache-Control "public, max-age=31536000, immutable"

    # Logging
    log {
        output file /var/log/caddy/appliances.log
    }
}
```

### 3. Deploy

```bash
# Create directory
sudo mkdir -p /var/www/appliances

# Copy files
sudo rsync -av registry/ /var/www/appliances/

# Reload Caddy
sudo systemctl reload caddy
```

Caddy automatically handles:
- HTTPS certificates (Let's Encrypt)
- Certificate renewal
- HTTP to HTTPS redirect

## Deployment: AWS S3 + CloudFront

### 1. Create S3 Bucket

```bash
aws s3 mb s3://appliances-example-com
```

### 2. Configure Bucket for Static Hosting

```bash
# Enable static website hosting
aws s3 website s3://appliances-example-com \
  --index-document index.json

# Set bucket policy (public read)
cat > bucket-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::appliances-example-com/*"
    }
  ]
}
EOF

aws s3api put-bucket-policy \
  --bucket appliances-example-com \
  --policy file://bucket-policy.json
```

### 3. Upload Registry

```bash
# Sync to S3
aws s3 sync registry/ s3://appliances-example-com/ \
  --delete \
  --cache-control "public, max-age=300" \
  --exclude "images/*"

# Images with longer cache
aws s3 sync registry/images/ s3://appliances-example-com/images/ \
  --delete \
  --cache-control "public, max-age=31536000, immutable"
```

### 4. Create CloudFront Distribution

```bash
# Create distribution
aws cloudfront create-distribution \
  --origin-domain-name appliances-example-com.s3.amazonaws.com \
  --default-root-object streams/v1/index.json

# Note the distribution domain name
# Configure custom domain with Route53 (optional)
```

### 5. Automated S3 Deployment

Update `scripts/publish.sh`:

```bash
PUBLISH_METHOD=s3 PUBLISH_DEST=s3://appliances-example-com ./scripts/publish.sh
```

## Deployment: GitHub Pages

### 1. Create Repository

```bash
# Create a new repository named 'appliances'
gh repo create appliances --public
```

### 2. Configure GitHub Pages

```yaml
# .github/workflows/publish.yml
name: Publish Registry

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  build-and-publish:
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        run: |
          sudo snap install distrobuilder --classic

      - name: Build appliances
        run: make build

      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./registry
          cname: appliances.example.com
```

### 3. Configure Custom Domain

In repository settings:
1. Go to Settings → Pages
2. Set custom domain: `appliances.example.com`
3. Enable "Enforce HTTPS"

Add DNS records:
```
CNAME appliances.example.com → username.github.io
```

## Deployment: Cloudflare Pages

### 1. Create Project

```bash
# Install Wrangler
npm install -g wrangler

# Login
wrangler login

# Create project
wrangler pages project create appliances
```

### 2. Configure Build

Create `wrangler.toml`:

```toml
name = "appliances"
compatibility_date = "2025-01-27"

[site]
bucket = "./registry"
```

### 3. Deploy

```bash
# Build registry
make build

# Deploy
wrangler pages publish registry
```

### 4. Custom Domain

In Cloudflare dashboard:
1. Pages → appliances → Custom domains
2. Add `appliances.example.com`
3. Configure DNS (automatic if using Cloudflare DNS)

## SSL/TLS Certificates

### Let's Encrypt (Certbot)

```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d appliances.example.com

# Auto-renewal is configured automatically
```

### Cloudflare Origin Certificate

For Cloudflare-proxied sites:

1. Cloudflare dashboard → SSL/TLS → Origin Server
2. Create certificate
3. Download certificate and key
4. Configure in web server

### Self-Signed (Testing Only)

```bash
openssl req -x509 -newkey rsa:4096 \
  -keyout key.pem -out cert.pem \
  -days 365 -nodes \
  -subj "/CN=appliances.example.com"
```

## Continuous Deployment

### GitHub Actions

```yaml
# .github/workflows/deploy.yml
name: Build and Deploy

on:
  push:
    branches: [main]
  schedule:
    - cron: '0 2 * * 0'  # Weekly rebuild

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Install distrobuilder
        run: sudo snap install distrobuilder --classic

      - name: Build appliances
        run: make build

      - name: Deploy to S3
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        run: |
          PUBLISH_METHOD=s3 \
          PUBLISH_DEST=s3://appliances-example-com \
          ./scripts/publish.sh
```

### GitLab CI

```yaml
# .gitlab-ci.yml
stages:
  - build
  - deploy

build:
  stage: build
  image: ubuntu:latest
  before_script:
    - apt-get update
    - apt-get install -y snapd
    - snap install distrobuilder --classic
  script:
    - make build
  artifacts:
    paths:
      - registry/

deploy:
  stage: deploy
  image: amazon/aws-cli
  script:
    - aws s3 sync registry/ s3://appliances-example-com/ --delete
  only:
    - main
```

## Monitoring

### Access Logs

Parse nginx logs for usage metrics:

```bash
# Most downloaded images
awk '/GET.*rootfs\.squashfs/ {print $7}' /var/log/nginx/appliances-access.log | \
  sort | uniq -c | sort -rn | head -10

# Bandwidth by image
awk '/GET.*rootfs\.squashfs/ {sum+=$10} END {print sum/1024/1024 " MB"}' \
  /var/log/nginx/appliances-access.log
```

### CloudWatch (AWS)

Enable S3 bucket metrics and CloudFront monitoring in AWS console.

### Uptime Monitoring

Use external monitoring:

```bash
# Check index.json accessibility
curl -sf https://appliances.example.com/streams/v1/index.json > /dev/null
```

Services: UptimeRobot, Pingdom, StatusCake

## Security

### Access Control

For private registries:

```nginx
# Nginx with HTTP Basic Auth
location / {
    auth_basic "Appliance Registry";
    auth_basic_user_file /etc/nginx/.htpasswd;
}
```

Create password file:
```bash
sudo htpasswd -c /etc/nginx/.htpasswd username
```

### Rate Limiting

```nginx
# Nginx rate limiting
limit_req_zone $binary_remote_addr zone=registry:10m rate=10r/s;

location / {
    limit_req zone=registry burst=20;
}
```

### IP Whitelisting

```nginx
# Allow specific IPs only
allow 192.168.1.0/24;
allow 10.0.0.0/8;
deny all;
```

## Backup

### Registry Backup

```bash
# Backup registry to tarball
tar -czf registry-backup-$(date +%Y%m%d).tar.gz registry/

# Backup to S3
aws s3 cp registry-backup-$(date +%Y%m%d).tar.gz \
  s3://backups/appliances/
```

### Source Backup

Registry is reproducible from source:

```bash
# Version control
git commit -am "Update appliances"
git push

# Rebuild anytime
make clean-all
make build
```

## Troubleshooting

### 404 Errors

Check file permissions:
```bash
sudo find /var/www/appliances -type d -exec chmod 755 {} \;
sudo find /var/www/appliances -type f -exec chmod 644 {} \;
```

### SSL Errors

Test certificate:
```bash
openssl s_client -connect appliances.example.com:443
```

### CORS Issues

Ensure headers are set:
```bash
curl -I https://appliances.example.com/streams/v1/index.json | grep -i access-control
```

## Performance Optimization

### Enable Compression

```nginx
# Nginx gzip
gzip on;
gzip_types application/json application/x-tar;
gzip_min_length 1000;
```

### CDN Integration

Point Cloudflare at origin:

1. DNS → Add A/CNAME record
2. Enable proxy (orange cloud)
3. SSL/TLS → Full

### Object Storage

Use S3 Transfer Acceleration:

```bash
aws s3 sync registry/ s3://appliances-example-com/ \
  --endpoint-url https://appliances-example-com.s3-accelerate.amazonaws.com
```

## Migration

### From Test to Production

```bash
# Export from test
rsync -av root@test-server:/var/www/appliances/ ./registry-test/

# Deploy to production
rsync -av ./registry-test/ root@prod-server:/var/www/appliances/
```

### Between Providers

```bash
# S3 to GCS
gsutil -m rsync -r s3://old-bucket gs://new-bucket
```

## Cost Estimation

### Nginx on VPS

- Server: $5-10/month (1GB RAM)
- Bandwidth: ~$0.01/GB
- SSL: Free (Let's Encrypt)

### AWS S3 + CloudFront

- Storage: $0.023/GB/month
- Requests: $0.0004/1000 requests
- Transfer: $0.085/GB (first 10TB)
- CloudFront: $0.085/GB

### GitHub Pages

- Free for public repos
- 100GB/month bandwidth
- Custom domain supported

## Resources

- [Nginx Documentation](https://nginx.org/en/docs/)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [AWS S3 Static Hosting](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html)
- [GitHub Pages](https://docs.github.com/en/pages)
- [Cloudflare Pages](https://developers.cloudflare.com/pages/)
