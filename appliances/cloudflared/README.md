# Cloudflare Tunnel Appliance

A Cloudflare Tunnel (cloudflared) appliance for securely exposing local services to the internet via Cloudflare's network.

## Quick Start

```bash
# Launch the appliance
incus launch appliance:cloudflared my-tunnel

# Configure with your tunnel token
incus exec my-tunnel -- bash -c 'echo "TUNNEL_TOKEN=eyJ..." > /etc/cloudflared/token.env'
incus exec my-tunnel -- chmod 600 /etc/cloudflared/token.env

# Start the tunnel
incus exec my-tunnel -- systemctl enable --now cloudflared-token

# Check status
incus exec my-tunnel -- systemctl status cloudflared-token
```

## Getting a Tunnel Token

1. Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Navigate to **Networks** > **Tunnels**
3. Click **Create a tunnel**
4. Choose **Cloudflared** connector
5. Copy the tunnel token (starts with `eyJ...`)

## Configuration

### Method 1: Token at Launch (Recommended)

Pass the tunnel token via cloud-init:

```yaml
#cloud-config
write_files:
  - path: /etc/cloudflared/token.env
    permissions: '0600'
    owner: cloudflared:cloudflared
    content: |
      TUNNEL_TOKEN=eyJhIjoiNz...
runcmd:
  - systemctl enable --now cloudflared-token
```

Launch with:

```bash
incus launch appliance:cloudflared my-tunnel --config cloud-init.user-data="$(cat cloud-config.yaml)"
```

### Method 2: Manual Configuration

```bash
# Set the tunnel token
incus exec my-tunnel -- bash -c 'echo "TUNNEL_TOKEN=eyJ..." > /etc/cloudflared/token.env'
incus exec my-tunnel -- chmod 600 /etc/cloudflared/token.env
incus exec my-tunnel -- chown cloudflared:cloudflared /etc/cloudflared/token.env

# Start the service
incus exec my-tunnel -- systemctl enable --now cloudflared-token
```

### Method 3: Credentials File Mode

For advanced configurations using a credentials file:

```bash
# Copy credentials file
incus file push credentials.json my-tunnel/etc/cloudflared/

# Create config file
incus exec my-tunnel -- bash -c 'cat > /etc/cloudflared/config.yml << EOF
tunnel: <TUNNEL-UUID>
credentials-file: /etc/cloudflared/credentials.json

ingress:
  - hostname: app.example.com
    service: http://localhost:8080
  - hostname: api.example.com
    service: http://localhost:3000
  - service: http_status:404
EOF'

# Set permissions
incus exec my-tunnel -- chown -R cloudflared:cloudflared /etc/cloudflared
incus exec my-tunnel -- chmod 600 /etc/cloudflared/credentials.json

# Use the standard service (not token mode)
incus exec my-tunnel -- systemctl enable --now cloudflared
```

## Exposing Services from Other Containers

Cloudflare Tunnel can expose services running in other containers:

```bash
# Get the IP of your web server container
incus list my-webserver -c4 --format csv | cut -d' ' -f1

# Configure the tunnel to point to that IP
# In Cloudflare Zero Trust Dashboard:
# - Public hostname: app.example.com
# - Service: http://10.x.x.x:80
```

## Multiple Tunnels

Run multiple tunnel instances for different purposes:

```bash
incus launch appliance:cloudflared tunnel-web
incus launch appliance:cloudflared tunnel-api

# Configure each with different tokens
```

## Troubleshooting

### Check Service Status

```bash
incus exec my-tunnel -- systemctl status cloudflared-token
incus exec my-tunnel -- journalctl -u cloudflared-token -f
```

### Test Connectivity

```bash
incus exec my-tunnel -- cloudflared tunnel info
```

### Verify Token

```bash
incus exec my-tunnel -- cat /etc/cloudflared/token.env
```

### Common Issues

**Service won't start:**
- Verify token is correct and not expired
- Check network connectivity: `incus exec my-tunnel -- curl -I https://cloudflare.com`

**Tunnel disconnects:**
- Check logs: `incus exec my-tunnel -- journalctl -u cloudflared-token`
- Verify the tunnel still exists in Cloudflare dashboard

## Ports

This appliance uses outbound connections only. No inbound ports are required.

| Direction | Port | Description |
|-----------|------|-------------|
| Outbound | 443 | HTTPS to Cloudflare |
| Outbound | 7844 | QUIC to Cloudflare (optional) |

## Volumes

| Path | Description |
|------|-------------|
| `/etc/cloudflared` | Configuration and credentials |

## Health Check

```bash
incus exec my-tunnel -- pgrep cloudflared && echo "Running" || echo "Not running"
```

## Security Notes

- The tunnel token grants access to your Cloudflare tunnel - keep it secret
- Use restrictive file permissions (600) on token.env and credentials files
- Rotate tokens periodically via Cloudflare dashboard
- Consider using Cloudflare Access policies for additional security

## Resource Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 1 core | 1 core |
| Memory | 64MB | 128MB |
| Disk | 128MB | 256MB |

## Tags

`networking`, `tunnel`, `cloudflare`, `reverse-proxy`, `zero-trust`
