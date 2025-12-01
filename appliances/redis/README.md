# Redis Appliance

A Redis in-memory data store appliance with cloud-init support for automated configuration.

## Quick Start

```bash
# Launch the appliance
incus launch appliance:redis my-redis

# Check status
incus exec my-redis -- redis-cli ping

# Connect to Redis CLI
incus exec my-redis -- redis-cli
```

## Configuration

### Default Setup

- Redis listens on all interfaces (0.0.0.0:6379)
- No authentication required by default (configure a password for production)
- AOF persistence enabled (appendonly yes)
- Protected mode disabled to allow remote connections

### Setting a Password

For production use, always set a password:

```bash
# Set password via redis-cli
incus exec my-redis -- redis-cli CONFIG SET requirepass "your-secure-password"
incus exec my-redis -- redis-cli CONFIG REWRITE

# Or edit the config file
incus exec my-redis -- bash -c 'echo "requirepass your-secure-password" >> /etc/redis/redis-appliance.conf'
incus exec my-redis -- systemctl restart redis-server
```

### Using cloud-init

Automate configuration using cloud-init:

```yaml
#cloud-config
runcmd:
  # Set Redis password
  - redis-cli CONFIG SET requirepass "your-secure-password"
  - redis-cli -a "your-secure-password" CONFIG REWRITE
  # Set max memory
  - redis-cli -a "your-secure-password" CONFIG SET maxmemory 256mb
  - redis-cli -a "your-secure-password" CONFIG SET maxmemory-policy allkeys-lru
  - redis-cli -a "your-secure-password" CONFIG REWRITE
```

Apply with:

```bash
incus launch appliance:redis my-redis --config cloud-init.user-data="$(cat cloud-config.yaml)"
```

## Persistence

Redis is configured with AOF (Append Only File) persistence by default. For production, attach a storage volume:

```bash
# Create a storage volume
incus storage volume create default redis-data

# Launch with the volume attached
incus launch appliance:redis my-redis --device data,source=redis-data,path=/var/lib/redis
```

### Persistence Options

The appliance uses AOF persistence by default. You can also enable RDB snapshots:

```bash
incus exec my-redis -- redis-cli CONFIG SET save "900 1 300 10 60 10000"
incus exec my-redis -- redis-cli CONFIG REWRITE
```

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 6379 | TCP | Redis |

## Volumes

| Path | Description |
|------|-------------|
| `/var/lib/redis` | Data files (RDB/AOF) |
| `/var/log/redis` | Log files |
| `/etc/redis` | Configuration files |

## Health Check

```bash
incus exec my-redis -- redis-cli ping
# Expected output: PONG
```

## Common Operations

### Get server info
```bash
incus exec my-redis -- redis-cli INFO
```

### Monitor commands in real-time
```bash
incus exec my-redis -- redis-cli MONITOR
```

### Check memory usage
```bash
incus exec my-redis -- redis-cli INFO memory
```

### Flush all data (careful!)
```bash
incus exec my-redis -- redis-cli FLUSHALL
```

## Resource Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 1 core | 1+ cores |
| Memory | 128MB | 512MB+ |
| Disk | 256MB | 1GB+ |

## Tags

`database`, `cache`, `key-value`, `nosql`
