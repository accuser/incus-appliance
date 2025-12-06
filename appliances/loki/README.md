# Loki Appliance

A Grafana Loki log aggregation system for collecting, storing, and querying logs.

## Quick Start

```bash
# Launch the appliance
incus launch appliance:loki my-loki

# Check status
incus exec my-loki -- systemctl status loki

# Access API
echo "http://$(incus list my-loki -c4 --format csv | cut -d' ' -f1):3100"
```

## Configuration

### Default Setup

- HTTP API on port 3100
- Filesystem storage backend
- 31-day retention period
- Single-node mode (no clustering)
- Multi-tenancy disabled

### Push Logs

#### Using curl

```bash
# Push a single log entry
curl -X POST http://localhost:3100/loki/api/v1/push \
  -H "Content-Type: application/json" \
  -d '{
    "streams": [{
      "stream": {"app": "myapp", "env": "prod"},
      "values": [["'"$(date +%s)000000000"'", "Application started"]]
    }]
  }'
```

#### Using Promtail

Deploy the Promtail appliance or configure an existing Promtail instance:

```yaml
clients:
  - url: http://loki:3100/loki/api/v1/push
```

#### Using Docker/Podman Log Driver

```bash
docker run --log-driver=loki \
  --log-opt loki-url="http://loki:3100/loki/api/v1/push" \
  --log-opt loki-retries=5 \
  --log-opt loki-batch-size=400 \
  nginx
```

### Query Logs

#### Using curl

```bash
# Query logs for an app
curl -sG http://localhost:3100/loki/api/v1/query \
  --data-urlencode 'query={app="myapp"}'

# Query with time range (last hour)
curl -sG http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={app="myapp"}' \
  --data-urlencode "start=$(date -d '1 hour ago' +%s)" \
  --data-urlencode "end=$(date +%s)"

# Search for text pattern
curl -sG http://localhost:3100/loki/api/v1/query \
  --data-urlencode 'query={app="myapp"} |= "error"'
```

#### Using LogCLI

```bash
# Install logcli
curl -fsSL -o logcli.zip https://github.com/grafana/loki/releases/download/v3.6.2/logcli-linux-amd64.zip
unzip logcli.zip && mv logcli-linux-amd64 /usr/local/bin/logcli

# Query logs
export LOKI_ADDR=http://localhost:3100
logcli query '{app="myapp"}'
logcli query '{app="myapp"} |= "error"' --tail
```

### Storage Configuration

Edit `/etc/loki/loki-config.yaml` for different storage backends:

#### S3 Storage

```yaml
common:
  storage:
    s3:
      endpoint: s3.amazonaws.com
      bucketnames: my-loki-bucket
      region: us-east-1
      access_key_id: ${AWS_ACCESS_KEY_ID}
      secret_access_key: ${AWS_SECRET_ACCESS_KEY}
```

#### MinIO Storage

```yaml
common:
  storage:
    s3:
      endpoint: minio:9000
      bucketnames: loki
      access_key_id: minioadmin
      secret_access_key: minioadmin
      insecure: true
      s3forcepathstyle: true
```

### Retention Settings

Edit `/etc/loki/loki-config.yaml`:

```yaml
limits_config:
  retention_period: 720h  # 30 days

compactor:
  retention_enabled: true
  retention_delete_delay: 2h
```

### Multi-Tenancy

Enable multi-tenancy in `/etc/loki/loki-config.yaml`:

```yaml
auth_enabled: true
```

Then use the `X-Scope-OrgID` header:

```bash
curl -X POST http://localhost:3100/loki/api/v1/push \
  -H "X-Scope-OrgID: tenant1" \
  -H "Content-Type: application/json" \
  -d '{"streams":[...]}'
```

### Using cloud-init

Automate configuration at launch:

```yaml
#cloud-config
write_files:
  - path: /etc/loki/loki-config.yaml
    content: |
      auth_enabled: false
      server:
        http_listen_port: 3100
      # ... custom configuration
runcmd:
  - systemctl restart loki
```

Apply with:

```bash
incus launch appliance:loki my-loki --config cloud-init.user-data="$(cat cloud-config.yaml)"
```

## Persistence

For production, attach a storage volume:

```bash
# Create a storage volume
incus storage volume create default loki-data

# Launch with the volume attached
incus launch appliance:loki my-loki \
  --device data,source=loki-data,path=/var/lib/loki
```

## Integration with Grafana

Add Loki as a data source in Grafana:

1. Go to Configuration → Data Sources
2. Add data source → Loki
3. Set URL: `http://loki:3100`
4. Save & Test

Example LogQL queries in Grafana:

```logql
# All logs from an app
{app="myapp"}

# Filter by level
{app="myapp"} | json | level="error"

# Count errors per minute
count_over_time({app="myapp"} |= "error" [1m])

# Top 10 error messages
topk(10, sum by (message) (count_over_time({app="myapp"} | json | level="error" [1h])))
```

## API Examples

### Health Check

```bash
curl -s http://localhost:3100/ready
curl -s http://localhost:3100/metrics
```

### Get Labels

```bash
curl -s http://localhost:3100/loki/api/v1/labels
curl -s http://localhost:3100/loki/api/v1/label/app/values
```

### Get Series

```bash
curl -sG http://localhost:3100/loki/api/v1/series \
  --data-urlencode 'match[]={app=~".+"}'
```

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 3100 | TCP | HTTP API (push/query) |
| 9096 | TCP | gRPC (internal) |

## Volumes

| Path | Description |
|------|-------------|
| `/var/lib/loki` | Log data storage |
| `/etc/loki` | Configuration files |

## Health Check

```bash
incus exec my-loki -- curl -sf localhost:3100/ready
```

## Common Operations

### Reload Configuration

```bash
incus exec my-loki -- systemctl reload loki
```

### Check Storage Usage

```bash
incus exec my-loki -- du -sh /var/lib/loki
```

### View Logs

```bash
incus exec my-loki -- journalctl -u loki -f
```

### Flush Ingester

```bash
curl -X POST http://localhost:3100/flush
```

## Resource Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 1 core | 2+ cores |
| Memory | 256MB | 1GB+ |
| Disk | 1GB | 10GB+ |

Memory and disk requirements scale with log volume and retention period.

## Tags

`logging`, `logs`, `aggregation`, `observability`, `grafana`, `loki`
