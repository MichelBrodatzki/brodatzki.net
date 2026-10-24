#!/usr/bin/env bash
set -euo pipefail

umask 077

usage() {
  cat >&2 <<'EOF'
Usage:
  create-client-cert.sh \
    --common-name <name> \
    --ca-cert <path> \
    --ca-key <path> \
    --out-dir <path> \
    [--days <days>]

Options:
  --common-name  Subject common name for the client certificate.
  --hostname     Deprecated alias for --common-name.
  --ca-cert      PEM-encoded CA certificate.
  --ca-key       PEM-encoded CA private key.
  --out-dir      Directory in which to create the key and certificate.
  --days         Certificate lifetime in days (default: 365).
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

require_value() {
  [[ $# -ge 2 && -n "$2" ]] || die "Option $1 requires a value"
}

COMMON_NAME=""
CA_CERT=""
CA_KEY=""
OUT_DIR=""
DAYS=365

while [[ $# -gt 0 ]]; do
  case "$1" in
    --common-name | --hostname)
      require_value "$@"
      COMMON_NAME="$2"
      shift 2
      ;;
    --ca-cert)
      require_value "$@"
      CA_CERT="$2"
      shift 2
      ;;
    --ca-key)
      require_value "$@"
      CA_KEY="$2"
      shift 2
      ;;
    --out-dir)
      require_value "$@"
      OUT_DIR="$2"
      shift 2
      ;;
    --days)
      require_value "$@"
      DAYS="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage
      die "Unknown option: $1"
      ;;
  esac
done

[[ -n "$COMMON_NAME" ]] || die "--common-name is required"
[[ -n "$CA_CERT" ]] || die "--ca-cert is required"
[[ -n "$CA_KEY" ]] || die "--ca-key is required"
[[ -n "$OUT_DIR" ]] || die "--out-dir is required"
[[ "$DAYS" =~ ^[1-9][0-9]*$ ]] || die "--days must be a positive integer"
[[ "$COMMON_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9._\ -]*$ ]] || \
  die "--common-name may only contain letters, digits, spaces, dots, underscores, and hyphens"
[[ -s "$CA_CERT" ]] || die "CA certificate does not exist or is empty: $CA_CERT"
[[ -s "$CA_KEY" ]] || die "CA private key does not exist or is empty: $CA_KEY"
command -v openssl >/dev/null 2>&1 || die "openssl is required"

FILE_STEM="${COMMON_NAME//[^a-zA-Z0-9._-]/_}"
[[ -n "$FILE_STEM" && "$FILE_STEM" != "." && "$FILE_STEM" != ".." ]] || \
  die "The common name cannot be converted to a safe filename"

mkdir -p "$OUT_DIR"

KEY_FILE="$OUT_DIR/$FILE_STEM.key.pem"
CERT_FILE="$OUT_DIR/$FILE_STEM.cert.pem"

[[ ! -e "$KEY_FILE" ]] || die "Refusing to overwrite existing key: $KEY_FILE"
[[ ! -e "$CERT_FILE" ]] || die "Refusing to overwrite existing certificate: $CERT_FILE"

TEMP_DIR="$(mktemp -d)"
CSR_FILE="$TEMP_DIR/client.csr.pem"
EXT_FILE="$TEMP_DIR/client.ext"

cleanup() {
  rm -f "$CSR_FILE" "$EXT_FILE"
  rmdir "$TEMP_DIR" 2>/dev/null || true
}
trap cleanup EXIT

openssl genpkey \
  -algorithm RSA \
  -pkeyopt rsa_keygen_bits:4096 \
  -out "$KEY_FILE"

openssl req \
  -new \
  -sha256 \
  -key "$KEY_FILE" \
  -out "$CSR_FILE" \
  -subj "/CN=$COMMON_NAME"

cat >"$EXT_FILE" <<'EOF'
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = clientAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
EOF

openssl x509 \
  -req \
  -sha256 \
  -in "$CSR_FILE" \
  -CA "$CA_CERT" \
  -CAkey "$CA_KEY" \
  -CAcreateserial \
  -out "$CERT_FILE" \
  -days "$DAYS" \
  -extfile "$EXT_FILE"

chmod 0400 "$KEY_FILE"
chmod 0444 "$CERT_FILE"

openssl verify \
  -CAfile "$CA_CERT" \
  -purpose sslclient \
  "$CERT_FILE"

echo
echo "Created client certificate:"
echo "  Common name: $COMMON_NAME"
echo "  Private key: $KEY_FILE"
echo "  Certificate: $CERT_FILE"
echo "  Validity: $DAYS days"
