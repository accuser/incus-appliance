# Incus Profiles

Profiles provide reusable configuration for appliance instances.

## Available Profiles

### appliance-base

Base configuration for all appliances with sensible defaults.

```bash
# Create the profile
incus profile create appliance-base
cat profiles/appliance-base.yaml | incus profile edit appliance-base

# Use with appliances
incus launch appliance:nginx my-nginx --profile default --profile appliance-base
```

## Creating Custom Profiles

### Example: Nginx Proxy Profile

```yaml
# profiles/nginx-proxy.yaml
description: Nginx reverse proxy with port forwarding

config:
  limits.memory: 256MB

devices:
  http:
    type: proxy
    listen: tcp:0.0.0.0:80
    connect: tcp:127.0.0.1:80
  https:
    type: proxy
    listen: tcp:0.0.0.0:443
    connect: tcp:127.0.0.1:443
```

Apply:
```bash
incus profile create nginx-proxy
cat profiles/nginx-proxy.yaml | incus profile edit nginx-proxy
incus launch appliance:nginx my-proxy --profile default --profile nginx-proxy
```

## Profile Inheritance

Profiles are applied in order, with later profiles overriding earlier ones:

```bash
# default provides: networking, storage basics
# appliance-base adds: resource limits, cloud-init
# nginx-proxy adds: port forwarding
incus launch appliance:nginx my-nginx \
  --profile default \
  --profile appliance-base \
  --profile nginx-proxy
```

## Common Profile Patterns

### Resource Limits

```yaml
config:
  limits.cpu: "2"
  limits.memory: "1GB"
  limits.memory.swap: "false"
```

### Persistent Storage

```yaml
devices:
  data:
    type: disk
    source: my-storage-volume
    path: /var/lib/myapp
```

### Port Forwarding

```yaml
devices:
  port8080:
    type: proxy
    listen: tcp:0.0.0.0:8080
    connect: tcp:127.0.0.1:8080
```

### Cloud-init Configuration

```yaml
config:
  cloud-init.user-data: |
    #cloud-config
    timezone: America/New_York
    write_files:
      - path: /etc/myapp/config.yml
        content: |
          port: 8080
          debug: false
```

## See Also

- [Incus Profiles Documentation](https://linuxcontainers.org/incus/docs/main/profiles/)
- [Appliance-specific profiles](../appliances/)
