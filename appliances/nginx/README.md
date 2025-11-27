# Nginx Appliance

A lightweight, production-ready Nginx reverse proxy and web server appliance based on Alpine Linux.

## Quick Start

```bash
# Launch the appliance
incus launch appliance:nginx my-proxy

# Check status
incus exec my-proxy -- nginx -t

# View the default page
incus exec my-proxy -- curl -s localhost
```

## Features

- **Minimal footprint**: Alpine Linux base (~50MB)
- **Production-ready**: Optimized configuration with gzip, security headers
- **Health endpoint**: Built-in `/health` endpoint for monitoring
- **Log rotation**: Automatic log rotation configured
- **Easy configuration**: Drop configs in `/etc/nginx/conf.d/`

## Configuration

### Adding a Site

Create a configuration file on your host:

```nginx
# mysite.conf
server {
    listen 80;
    server_name example.com;

    location / {
        proxy_pass http://backend:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

Push it to the appliance:

```bash
incus file push mysite.conf my-proxy/etc/nginx/conf.d/
incus exec my-proxy -- nginx -t
incus exec my-proxy -- nginx -s reload
```

### Editing Configuration

```bash
# Edit config inside the container
incus exec my-proxy -- vi /etc/nginx/conf.d/default.conf

# Test and reload
incus exec my-proxy -- nginx -t && nginx -s reload
```

## Networking

Expose ports using Incus devices:

```bash
# Proxy port 80 from host to container
incus config device add my-proxy http proxy listen=tcp:0.0.0.0:80 connect=tcp:127.0.0.1:80

# Proxy port 443 for HTTPS
incus config device add my-proxy https proxy listen=tcp:0.0.0.0:443 connect=tcp:127.0.0.1:443
```

## Persistent Data

Important directories to persist (use disk devices or snapshots):

- `/etc/nginx/conf.d/` - Site configurations
- `/var/log/nginx/` - Log files
- `/usr/share/nginx/html/` - Static content

Example:

```bash
# Create a storage volume for configs
incus storage volume create default nginx-config
incus config device add my-proxy config disk source=nginx-config path=/etc/nginx/conf.d
```

## SSL/TLS Certificates

### Using Let's Encrypt with Certbot

```bash
# Install certbot inside the appliance
incus exec my-proxy -- apk add certbot

# Obtain a certificate
incus exec my-proxy -- certbot certonly --webroot -w /usr/share/nginx/html -d example.com

# Configure nginx to use the certificate
incus exec my-proxy -- vi /etc/nginx/conf.d/ssl.conf
```

### Using External Certificates

```bash
# Push certificates to the appliance
incus file push cert.pem my-proxy/etc/nginx/ssl/cert.pem
incus file push key.pem my-proxy/etc/nginx/ssl/key.pem

# Set permissions
incus exec my-proxy -- chmod 600 /etc/nginx/ssl/key.pem
```

## Monitoring

### Health Check

```bash
# Check health endpoint
incus exec my-proxy -- curl -sf http://localhost/health
```

### Logs

```bash
# Access logs
incus exec my-proxy -- tail -f /var/log/nginx/access.log

# Error logs
incus exec my-proxy -- tail -f /var/log/nginx/error.log

# Both
incus exec my-proxy -- tail -f /var/log/nginx/*.log
```

### Metrics

Check connection and request metrics:

```bash
incus exec my-proxy -- sh -c 'ps aux | grep nginx'
incus exec my-proxy -- sh -c 'netstat -an | grep :80'
```

## Common Tasks

### Reload Configuration

```bash
incus exec my-proxy -- nginx -s reload
```

### Test Configuration

```bash
incus exec my-proxy -- nginx -t
```

### Restart Nginx

```bash
incus exec my-proxy -- rc-service nginx restart
```

### View Version

```bash
incus exec my-proxy -- nginx -v
```

## Troubleshooting

### Configuration Errors

```bash
# Validate config syntax
incus exec my-proxy -- nginx -t

# Check error logs
incus exec my-proxy -- cat /var/log/nginx/error.log
```

### Service Not Starting

```bash
# Check service status
incus exec my-proxy -- rc-service nginx status

# View system logs
incus exec my-proxy -- dmesg | tail
```

### Permission Issues

```bash
# Check nginx user exists
incus exec my-proxy -- id nginx

# Fix permissions
incus exec my-proxy -- chown -R nginx:nginx /var/log/nginx
incus exec my-proxy -- chown -R nginx:nginx /var/cache/nginx
```

## Resource Requirements

- **Minimum CPU**: 1 core
- **Minimum Memory**: 128MB
- **Minimum Disk**: 256MB
- **Recommended Memory**: 256MB
- **Recommended Disk**: 1GB

## See Also

- [Traefik Appliance](../traefik/) - Modern reverse proxy with automatic HTTPS
- [Caddy Appliance](../caddy/) - Web server with automatic HTTPS
