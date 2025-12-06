# Mosquitto MQTT Broker Appliance

An Eclipse Mosquitto MQTT broker appliance with cloud-init support for automated configuration.

## Quick Start

```bash
# Launch the appliance
incus launch appliance:mosquitto my-mqtt

# Check status
incus exec my-mqtt -- systemctl status mosquitto

# Test pub/sub
incus exec my-mqtt -- mosquitto_sub -t 'test/#' -v &
incus exec my-mqtt -- mosquitto_pub -t 'test/hello' -m 'world'
```

## Configuration

### Default Setup

- MQTT listener on port 1883 (all interfaces)
- Anonymous connections allowed
- Persistence enabled
- WebSocket and TLS disabled by default

### Enabling Authentication

For production use, enable password authentication:

```bash
# Create password file with first user
incus exec my-mqtt -- mosquitto_passwd -c /etc/mosquitto/passwd myuser

# Add additional users
incus exec my-mqtt -- mosquitto_passwd /etc/mosquitto/passwd anotheruser

# Enable authentication
incus exec my-mqtt -- mv /etc/mosquitto/conf.d/auth.conf.disabled /etc/mosquitto/conf.d/auth.conf
incus exec my-mqtt -- systemctl restart mosquitto
```

### Enabling TLS

To enable TLS on port 8883:

```bash
# Copy your certificates
incus file push ca.crt my-mqtt/etc/mosquitto/certs/
incus file push server.crt my-mqtt/etc/mosquitto/certs/
incus file push server.key my-mqtt/etc/mosquitto/certs/

# Set permissions
incus exec my-mqtt -- chown -R mosquitto:mosquitto /etc/mosquitto/certs
incus exec my-mqtt -- chmod 600 /etc/mosquitto/certs/server.key

# Enable TLS config
incus exec my-mqtt -- mv /etc/mosquitto/conf.d/tls.conf.disabled /etc/mosquitto/conf.d/tls.conf
incus exec my-mqtt -- systemctl restart mosquitto
```

### Enabling WebSockets

To enable WebSocket listener on port 9001:

```bash
incus exec my-mqtt -- mv /etc/mosquitto/conf.d/websockets.conf.disabled /etc/mosquitto/conf.d/websockets.conf
incus exec my-mqtt -- systemctl restart mosquitto
```

### Using cloud-init

Automate configuration at launch:

```yaml
#cloud-config
runcmd:
  # Create users
  - mosquitto_passwd -b -c /etc/mosquitto/passwd sensor secret123
  - mosquitto_passwd -b /etc/mosquitto/passwd device secret456
  # Enable authentication
  - mv /etc/mosquitto/conf.d/auth.conf.disabled /etc/mosquitto/conf.d/auth.conf
  # Restart to apply
  - systemctl restart mosquitto
```

Apply with:

```bash
incus launch appliance:mosquitto my-mqtt --config cloud-init.user-data="$(cat cloud-config.yaml)"
```

## Persistence

For production, attach a storage volume to persist data across container restarts:

```bash
# Create a storage volume
incus storage volume create default mqtt-data

# Launch with the volume attached
incus launch appliance:mosquitto my-mqtt --device data,source=mqtt-data,path=/var/lib/mosquitto
```

## Connecting from Other Containers

```bash
# Get the container's IP
incus list my-mqtt -c4 --format csv | cut -d' ' -f1

# From another container, connect using the IP
mosquitto_pub -h 10.x.x.x -t 'sensors/temp' -m '22.5'
mosquitto_sub -h 10.x.x.x -t 'sensors/#' -v
```

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 1883 | TCP | MQTT |
| 8883 | TCP | MQTT over TLS (disabled by default) |
| 9001 | TCP | WebSocket (disabled by default) |

## Volumes

| Path | Description |
|------|-------------|
| `/var/lib/mosquitto` | Persistent data and retained messages |
| `/var/log/mosquitto` | Log files |
| `/etc/mosquitto` | Configuration files |

## Health Check

```bash
# Check if broker is responding
incus exec my-mqtt -- mosquitto_sub -t '$SYS/broker/uptime' -C 1 -W 2

# Check broker version
incus exec my-mqtt -- mosquitto_sub -t '$SYS/broker/version' -C 1 -W 2
```

## Common Operations

### View broker statistics
```bash
incus exec my-mqtt -- mosquitto_sub -t '$SYS/#' -v
```

### Monitor all messages
```bash
incus exec my-mqtt -- mosquitto_sub -t '#' -v
```

### Check connected clients
```bash
incus exec my-mqtt -- mosquitto_sub -t '$SYS/broker/clients/connected' -C 1 -W 2
```

### View logs
```bash
incus exec my-mqtt -- tail -f /var/log/mosquitto/mosquitto.log
```

### Reload configuration
```bash
incus exec my-mqtt -- systemctl reload mosquitto
```

## Resource Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 1 core | 1+ cores |
| Memory | 64MB | 256MB+ |
| Disk | 128MB | 512MB+ |

## Tags

`messaging`, `mqtt`, `iot`, `broker`, `pubsub`
