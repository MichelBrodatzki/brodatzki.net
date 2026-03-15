#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 --hostname <FQDN> --ca-cert <path> --ca-key <path> --out-dir <path>"
  exit 1
}

HOSTNAME=""
CA_CERT=""
CA_KEY=""
OUT_DIR="."

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hostname)  HOSTNAME="$2"; shift 2 ;;
    --ca-cert)   CA_CERT="$2"; shift 2 ;;
    --ca-key)    CA_KEY="$2"; shift 2 ;;
    --out-dir)   OUT_DIR="$2"; shift 2 ;;
    *)           usage ;;
  esac
done

if [[ -z "$HOSTNAME" || -z "$CA_CERT" || -z "$CA_KEY" ]]; then
  usage
fi

mkdir -p "$OUT_DIR"

KEY_FILE="$OUT_DIR/key.pem"
CSR_FILE="$(mktemp)"
CERT_FILE="$OUT_DIR/cert.pem"
EXT_FILE="$(mktemp)"

trap 'rm -f "$CSR_FILE" "$EXT_FILE"' EXIT

# Generate private key
openssl genrsa -out "$KEY_FILE" 4096

# Generate CSR
openssl req -new \
  -key "$KEY_FILE" \
  -out "$CSR_FILE" \
  -subj "/CN=$HOSTNAME"

# Write extensions
cat > "$EXT_FILE" <<EOF
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature
extendedKeyUsage = clientAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
EOF

# Sign with CA
openssl x509 -req \
  -in "$CSR_FILE" \
  -CA "$CA_CERT" \
  -CAkey "$CA_KEY" \
  -CAcreateserial \
  -out "$CERT_FILE" \
  -days 365 \
  -extfile "$EXT_FILE"

# Append CA cert to create bundle
cat "$CA_CERT" >> "$CERT_FILE"

echo ""
echo "Created:"
echo "  Private key: $KEY_FILE"
echo "  Certificate bundle (leaf + CA): $CERT_FILE"
