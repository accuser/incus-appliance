# Prometheus Node Exporter Appliance

A Prometheus node exporter appliance for collecting system metrics with cloud-init support.

## Quick Start

```bash
# Launch the appliance
incus launch appliance:node-exporter my-exporter

# Check status
incus exec my-exporter -- systemctl status prometheus-node-exporter

# View metrics
incus exec my-exporter -- curl -s localhost:9100/metrics | head -20
```

## Configuration

### Default Setup

- Metrics exposed on port 9100
- All default collectors enabled
- Textfile collector directory available at `/var/lib/prometheus/node-exporter`

### Prometheus Scrape Configuration

Add to your Prometheus configuration:

```yaml
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['<container-ip>:9100']
```

### Disabling Collectors

Edit `/etc/default/prometheus-node-exporter` to disable unwanted collectors:

```bash
incus exec my-exporter -- bash -c 'echo "ARGS=\"--web.listen-address=:9100 --no-collector.arp --no-collector.infiniband\"" > /etc/default/prometheus-node-exporter'
incus exec my-exporter -- systemctl restart prometheus-node-exporter
```

### Custom Metrics with Textfile Collector

Add custom metrics using the textfile collector:

```bash
# Create a custom metric file
incus exec my-exporter -- bash -c 'echo "my_custom_metric 42" > /var/lib/prometheus/node-exporter/custom.prom'

# Enable textfile collector
incus exec my-exporter -- bash -c 'echo "ARGS=\"--web.listen-address=:9100 --collector.textfile.directory=/var/lib/prometheus/node-exporter\"" > /etc/default/prometheus-node-exporter'
incus exec my-exporter -- systemctl restart prometheus-node-exporter

# Verify
incus exec my-exporter -- curl -s localhost:9100/metrics | grep my_custom
```

### Using cloud-init

Automate configuration at launch:

```yaml
#cloud-config
write_files:
  - path: /etc/default/prometheus-node-exporter
    content: |
      ARGS="--web.listen-address=:9100 --collector.textfile.directory=/var/lib/prometheus/node-exporter --no-collector.arp"
runcmd:
  - systemctl restart prometheus-node-exporter
```

Apply with:

```bash
incus launch appliance:node-exporter my-exporter --config cloud-init.user-data="$(cat cloud-config.yaml)"
```

## Available Collectors

Default collectors include:

| Collector | Description |
|-----------|-------------|
| cpu | CPU usage statistics |
| diskstats | Disk I/O statistics |
| filesystem | Filesystem usage |
| loadavg | System load average |
| meminfo | Memory statistics |
| netdev | Network device statistics |
| netstat | Network statistics |
| stat | System statistics |
| time | System time |
| uname | System information |
| vmstat | Virtual memory statistics |

See [node_exporter documentation](https://github.com/prometheus/node_exporter#collectors) for the full list.

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 9100 | TCP | Metrics endpoint |

## Volumes

This appliance is stateless and requires no persistent volumes.

For custom metrics using the textfile collector, `/var/lib/prometheus/node-exporter` is available.

## Health Check

```bash
incus exec my-exporter -- curl -sf localhost:9100/metrics >/dev/null && echo "OK"
```

## Common Metrics

### CPU Usage
```bash
incus exec my-exporter -- curl -s localhost:9100/metrics | grep "^node_cpu_seconds_total"
```

### Memory Usage
```bash
incus exec my-exporter -- curl -s localhost:9100/metrics | grep "^node_memory_"
```

### Disk Usage
```bash
incus exec my-exporter -- curl -s localhost:9100/metrics | grep "^node_filesystem_"
```

### Network Statistics
```bash
incus exec my-exporter -- curl -s localhost:9100/metrics | grep "^node_network_"
```

## Resource Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 1 core | 1 core |
| Memory | 32MB | 64MB |
| Disk | 64MB | 128MB |

## Tags

`monitoring`, `metrics`, `prometheus`, `observability`
