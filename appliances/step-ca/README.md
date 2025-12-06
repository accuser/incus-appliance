# step-ca Appliance

A Smallstep step-ca private certificate authority for issuing TLS certificates, running an ACME server, and managing PKI infrastructure.

## Quick Start

```bash
# Launch the appliance
incus launch appliance:step-ca my-ca

# Check status
incus exec my-ca -- systemctl status step-ca

# Get the root CA certificate
incus file pull my-ca/var/lib/step-ca/certs/root_ca.crt ./root_ca.crt

# Get the CA URL
echo "https://$(incus list my-ca -c4 --format csv | cut -d' ' -f1)"
```

## Security Warning

This appliance is intended for development, testing, and internal PKI use cases. For production deployments:

1. **Back up the CA keys** - The private keys in `/var/lib/step-ca/secrets/` are critical
2. **Secure the password** - Change the auto-generated password and store it securely
3. **Consider HSM integration** - For high-security environments, use a Hardware Security Module
4. **Network isolation** - Limit network access to the CA
5. **Regular audits** - Monitor certificate issuance logs

## Configuration

### Default Setup

- HTTPS/ACME endpoint on port 443
- Auto-generated root CA on first boot
- ACME provisioner enabled
- JWK provisioner (admin) enabled
- Badger database backend

### Customizing CA Initialization

Use environment variables via cloud-init:

```yaml
#cloud-config
write_files:
  - path: /etc/default/step-ca
    content: |
      STEP_CA_NAME="My Organization CA"
      STEP_CA_DNS="ca.example.com,localhost"
      STEP_CA_ADDRESS=":443"
runcmd:
  - source /etc/default/step-ca && /usr/local/bin/init-step-ca.sh
  - systemctl restart step-ca
```

### Using Your Own CA Certificate

To import an existing CA instead of generating one:

```bash
# Stop the CA
incus exec my-ca -- systemctl stop step-ca

# Copy your certificates
incus file push root_ca.crt my-ca/var/lib/step-ca/certs/root_ca.crt
incus file push intermediate_ca.crt my-ca/var/lib/step-ca/certs/intermediate_ca.crt
incus file push intermediate_ca_key my-ca/var/lib/step-ca/secrets/intermediate_ca_key

# Update configuration and restart
incus exec my-ca -- systemctl start step-ca
```

## Using ACME (Let's Encrypt Compatible)

### ACME Directory

The ACME directory URL is:
```
https://<ca-ip>/acme/acme/directory
```

### With certbot

```bash
# Get root CA certificate first
incus file pull my-ca/var/lib/step-ca/certs/root_ca.crt /usr/local/share/ca-certificates/step-ca.crt
update-ca-certificates

# Request a certificate
certbot certonly --standalone \
  --server https://ca.example.com/acme/acme/directory \
  -d myserver.example.com
```

### With step CLI

```bash
# Install step CLI on client
curl -fsSL https://github.com/smallstep/cli/releases/download/v0.28.6/step_linux_0.28.6_amd64.tar.gz | tar -xz
mv step_0.28.6/bin/step /usr/local/bin/

# Bootstrap client with CA root
step ca bootstrap --ca-url https://ca.example.com --fingerprint <ROOT_FINGERPRINT>

# Get a certificate
step ca certificate myserver.local server.crt server.key
```

### With acme.sh

```bash
# Set CA directory
export ACME_DIRECTORY="https://ca.example.com/acme/acme/directory"

# Issue certificate (use --insecure for self-signed CA root)
acme.sh --issue -d myserver.example.com --standalone --server "$ACME_DIRECTORY" --insecure
```

## Getting Certificates

### Interactive (JWK Provisioner)

```bash
# On the CA
incus exec my-ca -- step ca certificate myserver.local /tmp/server.crt /tmp/server.key

# Copy to host
incus file pull my-ca/tmp/server.crt ./
incus file pull my-ca/tmp/server.key ./
```

### Using the API

```bash
CA_URL="https://ca.example.com"
ROOT_CA="root_ca.crt"

# Get a certificate signing request token
TOKEN=$(step ca token myserver.local --ca-url=$CA_URL --root=$ROOT_CA)

# Sign the certificate
step ca certificate myserver.local server.crt server.key \
  --ca-url=$CA_URL --root=$ROOT_CA --token=$TOKEN
```

## Provisioners

### List Provisioners

```bash
incus exec my-ca -- step ca provisioner list
```

### Add OIDC Provisioner (Google, Okta, etc.)

```bash
incus exec my-ca -- step ca provisioner add google \
  --type=OIDC \
  --client-id=<CLIENT_ID> \
  --client-secret=<CLIENT_SECRET> \
  --configuration-endpoint=https://accounts.google.com/.well-known/openid-configuration \
  --domain=example.com
```

### Add SSH Provisioner

```bash
incus exec my-ca -- step ca provisioner add ssh-users --type=SSHPOP
```

## Persistence

For production, attach a storage volume:

```bash
# Create a storage volume
incus storage volume create default step-ca-data

# Launch with the volume attached
incus launch appliance:step-ca my-ca \
  --device data,source=step-ca-data,path=/var/lib/step-ca
```

## API Examples

### Health Check

```bash
curl -k https://localhost/health
# Or with CA cert:
curl --cacert root_ca.crt https://ca.example.com/health
```

### Get Root Certificate

```bash
curl -k https://localhost/root
```

### Get CA Fingerprint

```bash
incus exec my-ca -- step certificate fingerprint /var/lib/step-ca/certs/root_ca.crt
```

### List Certificates (requires admin)

```bash
step ca admin list
```

## Certificate Templates

Create custom certificate templates in `/var/lib/step-ca/templates/`:

```json
{
  "subject": {{ toJson .Subject }},
  "sans": {{ toJson .SANs }},
  "keyUsage": ["digitalSignature", "keyEncipherment"],
  "extKeyUsage": ["serverAuth", "clientAuth"],
  "basicConstraints": {
    "isCA": false,
    "maxPathLen": 0
  }
}
```

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 443 | TCP | HTTPS/ACME endpoint |
| 9000 | TCP | Admin API (optional) |

## Volumes

| Path | Description |
|------|-------------|
| `/var/lib/step-ca` | CA database, certificates, and keys |
| `/var/lib/step-ca/secrets` | Private keys and passwords (SENSITIVE) |
| `/var/lib/step-ca/certs` | Public certificates |
| `/var/lib/step-ca/config` | CA configuration |

## Health Check

```bash
incus exec my-ca -- curl -sf https://localhost/health --cacert /var/lib/step-ca/certs/root_ca.crt
```

## Common Operations

### View CA Configuration

```bash
incus exec my-ca -- cat /var/lib/step-ca/config/ca.json | jq
```

### Reload Configuration

```bash
incus exec my-ca -- systemctl reload step-ca
```

### View Logs

```bash
incus exec my-ca -- journalctl -u step-ca -f
```

### Revoke a Certificate

```bash
step ca revoke --serial=<SERIAL_NUMBER> --ca-url=https://ca.example.com --root=root_ca.crt
```

### Backup CA

```bash
# Create backup
incus exec my-ca -- tar -czf /tmp/step-ca-backup.tar.gz -C /var/lib step-ca
incus file pull my-ca/tmp/step-ca-backup.tar.gz ./

# Store securely - contains private keys!
```

### Restore CA

```bash
incus file push step-ca-backup.tar.gz my-ca/tmp/
incus exec my-ca -- bash -c "systemctl stop step-ca && rm -rf /var/lib/step-ca && tar -xzf /tmp/step-ca-backup.tar.gz -C /var/lib && chown -R step:step /var/lib/step-ca && systemctl start step-ca"
```

## Resource Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 1 core | 2+ cores |
| Memory | 256MB | 512MB+ |
| Disk | 1GB | 5GB+ |

## Troubleshooting

### CA Won't Start

Check logs:
```bash
incus exec my-ca -- journalctl -u step-ca -n 50
```

Verify password file:
```bash
incus exec my-ca -- cat /var/lib/step-ca/secrets/password.txt
```

### Certificate Errors

Verify root CA is trusted:
```bash
step certificate verify server.crt --roots root_ca.crt
```

### ACME Challenges Failing

Ensure port 443 is accessible and DNS resolves correctly.

## Tags

`security`, `pki`, `certificates`, `acme`, `tls`, `ca`
