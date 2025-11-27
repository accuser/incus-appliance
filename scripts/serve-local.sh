#!/usr/bin/env bash
set -euo pipefail

# Serve the registry locally for testing
# Generates self-signed certs and starts a simple HTTPS server

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REGISTRY_DIR="${PROJECT_ROOT}/registry"
CERTS_DIR="${PROJECT_ROOT}/.certs"
PORT="${PORT:-8443}"
HOST="${HOST:-localhost}"

# Validate registry exists
if [[ ! -d "$REGISTRY_DIR" ]]; then
  echo "Error: Registry directory not found at ${REGISTRY_DIR}"
  echo "Run 'make build' to create some appliances first."
  exit 1
fi

# Create certificates directory
mkdir -p "$CERTS_DIR"

# Generate self-signed certificate if not exists
if [[ ! -f "${CERTS_DIR}/server.crt" ]]; then
  echo "==> Generating self-signed certificate..."
  openssl req -x509 -newkey rsa:4096 \
    -keyout "${CERTS_DIR}/server.key" \
    -out "${CERTS_DIR}/server.crt" \
    -days 365 -nodes \
    -subj "/CN=${HOST}" \
    -addext "subjectAltName=DNS:${HOST},DNS:localhost,IP:127.0.0.1"
fi

echo "==> Starting HTTPS server on https://${HOST}:${PORT}"
echo "    Registry: ${REGISTRY_DIR}"
echo ""
echo "To add this remote:"
echo "  incus remote add appliance-test https://${HOST}:${PORT} --protocol simplestreams --accept-certificate"
echo ""
echo "To launch an appliance:"
echo "  incus launch appliance-test:nginx my-nginx"
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Use Python's http.server with SSL
cd "$REGISTRY_DIR"
python3 << EOF
import http.server
import ssl
import os

handler = http.server.SimpleHTTPRequestHandler
httpd = http.server.HTTPServer(('0.0.0.0', ${PORT}), handler)

context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain('${CERTS_DIR}/server.crt', '${CERTS_DIR}/server.key')
httpd.socket = context.wrap_socket(httpd.socket, server_side=True)

print(f"Serving on https://0.0.0.0:${PORT}")
httpd.serve_forever()
EOF
