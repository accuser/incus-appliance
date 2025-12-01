# PostgreSQL Appliance

A PostgreSQL database server appliance with cloud-init support for automated configuration.

## Quick Start

```bash
# Launch the appliance
incus launch appliance:postgresql my-postgres

# Check status
incus exec my-postgres -- systemctl status postgresql

# Connect to PostgreSQL
incus exec my-postgres -- sudo -u postgres psql
```

## Configuration

### Default Setup

- PostgreSQL is configured to accept local connections only
- Default database cluster is initialized automatically
- Runs as the `postgres` system user

### Enabling Remote Access

To allow remote connections, configure PostgreSQL after launch:

```bash
# Edit pg_hba.conf to allow remote connections
incus exec my-postgres -- bash -c 'echo "host all all 0.0.0.0/0 scram-sha-256" >> /etc/postgresql/*/main/pg_hba.conf'

# Edit postgresql.conf to listen on all interfaces
incus exec my-postgres -- bash -c "sed -i \"s/#listen_addresses = 'localhost'/listen_addresses = '*'/\" /etc/postgresql/*/main/postgresql.conf"

# Restart PostgreSQL
incus exec my-postgres -- systemctl restart postgresql
```

### Using cloud-init

You can automate configuration using cloud-init:

```yaml
#cloud-config
runcmd:
  # Set postgres user password
  - sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'your-secure-password';"
  # Create a database
  - sudo -u postgres createdb myapp
  # Enable remote access
  - echo "host all all 0.0.0.0/0 scram-sha-256" >> /etc/postgresql/*/main/pg_hba.conf
  - sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/*/main/postgresql.conf
  - systemctl restart postgresql
```

Apply with:

```bash
incus launch appliance:postgresql my-postgres --config cloud-init.user-data="$(cat cloud-config.yaml)"
```

## Persistence

For production use, attach a storage volume for database data:

```bash
# Create a storage volume
incus storage volume create default postgres-data

# Launch with the volume attached
incus launch appliance:postgresql my-postgres --device data,source=postgres-data,path=/var/lib/postgresql
```

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 5432 | TCP | PostgreSQL |

## Volumes

| Path | Description |
|------|-------------|
| `/var/lib/postgresql` | Database data files |
| `/var/log/postgresql` | Log files |
| `/etc/postgresql` | Configuration files |

## Health Check

```bash
incus exec my-postgres -- pg_isready -U postgres
```

## Resource Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 1 core | 2+ cores |
| Memory | 256MB | 1GB+ |
| Disk | 1GB | 10GB+ |

## Tags

`database`, `sql`, `relational`
