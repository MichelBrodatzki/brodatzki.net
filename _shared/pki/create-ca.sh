#!/usr/bin/env bash
set -euo pipefail

umask 077

usage() {
  cat >&2 <<'EOF'
Usage:
  create-ca.sh \
    --common-name <name> \
    --out-dir <path> \
    [--days <days>]

Options:
  --common-name  Subject common name for the CA certificate.
  --out-dir      Directory in which to create the CA key and certificate.
  --days         CA certificate lifetime in days (default: 3650).
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
OUT_DIR=""
DAYS=3650

while [[ $# -gt 0 ]]; do
  case "$1" in
    --common-name)
      require_value "$@"
      COMMON_NAME="$2"
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
[[ -n "$OUT_DIR" ]] || die "--out-dir is required"
[[ "$DAYS" =~ ^[1-9][0-9]*$ ]] || die "--days must be a positive integer"
[[ "$COMMON_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9._\ -]*$ ]] || \
  die "--common-name may only contain letters, digits, spaces, dots, underscores, and hyphens"
command -v openssl >/dev/null 2>&1 || die "openssl is required"

FILE_STEM="${COMMON_NAME//[^a-zA-Z0-9._-]/_}"
[[ -n "$FILE_STEM" && "$FILE_STEM" != "." && "$FILE_STEM" != ".." ]] || \
  die "The common name cannot be converted to a safe filename"

mkdir -p "$OUT_DIR"

KEY_FILE="$OUT_DIR/$FILE_STEM.key.pem"
CERT_FILE="$OUT_DIR/$FILE_STEM.cert.pem"

[[ ! -e "$KEY_FILE" ]] || die "Refusing to overwrite existing key: $KEY_FILE"
[[ ! -e "$CERT_FILE" ]] || die "Refusing to overwrite existing certificate: $CERT_FILE"

read -r -s -p "CA key passphrase: " CA_PASSPHRASE
echo
read -r -s -p "Confirm CA key passphrase: " CA_PASSPHRASE_CONFIRMATION
echo

[[ -n "$CA_PASSPHRASE" ]] || die "The CA key passphrase cannot be empty"
[[ ${#CA_PASSPHRASE} -ge 12 ]] || die "The CA key passphrase must contain at least 12 characters"
[[ "$CA_PASSPHRASE" == "$CA_PASSPHRASE_CONFIRMATION" ]] || die "Passphrases do not match"
unset CA_PASSPHRASE_CONFIRMATION

openssl genpkey \
  -algorithm RSA \
  -pkeyopt rsa_keygen_bits:4096 \
  -aes-256-cbc \
  -pass fd:3 \
  -out "$KEY_FILE" \
  3<<<"$CA_PASSPHRASE"

openssl req \
  -x509 \
  -new \
  -sha256 \
  -key "$KEY_FILE" \
  -passin fd:3 \
  -out "$CERT_FILE" \
  -days "$DAYS" \
  -subj "/CN=$COMMON_NAME" \
  -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -addext "subjectKeyIdentifier=hash" \
  3<<<"$CA_PASSPHRASE"

unset CA_PASSPHRASE

chmod 0400 "$KEY_FILE"
chmod 0444 "$CERT_FILE"

openssl verify \
  -CAfile "$CERT_FILE" \
  "$CERT_FILE"

echo
echo "Created certificate authority:"
echo "  Common name: $COMMON_NAME"
echo "  Private key: $KEY_FILE"
echo "  Certificate: $CERT_FILE"
echo "  Validity: $DAYS days"
echo
echo "Keep the private key and its passphrase outside the repository."
echo "The certificate is public and may be committed."
