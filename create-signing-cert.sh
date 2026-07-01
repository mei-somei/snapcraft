#!/bin/bash
# One-time setup: create a stable, self-signed code-signing certificate so the
# Screen Recording (TCC) permission survives rebuilds.
#
# Why this is needed:
#   Ad-hoc signing (`codesign --sign -`) pins TCC grants to the binary's CDHash,
#   which changes on every rebuild — so macOS re-prompts for screen recording
#   each time. A named self-signed identity gives a stable Designated
#   Requirement (anchored to the certificate, not the CDHash), so the grant
#   persists across rebuilds.
#
# Run once:  ./create-signing-cert.sh
# Then build with ./build-app.sh as usual.
set -euo pipefail

IDENTITY="SnapCraft Self-Signed"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Already installed? Nothing to do.
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
  echo "✓ Signing identity \"$IDENTITY\" already exists. Nothing to do."
  exit 0
fi

echo "▸ Generating self-signed code-signing certificate \"$IDENTITY\"…"

cat > "$TMP/cert.cfg" <<'EOF'
[ req ]
distinguished_name = dn
x509_extensions    = v3
prompt             = no
[ dn ]
CN = SnapCraft Self-Signed
[ v3 ]
basicConstraints   = critical, CA:false
keyUsage           = critical, digitalSignature
extendedKeyUsage   = critical, codeSigning
EOF

# Self-signed cert + key, 10-year validity.
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
  -config "$TMP/cert.cfg" >/dev/null 2>&1

# Bundle into a password-less PKCS#12 for import.
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -out "$TMP/cert.p12" -passout pass: >/dev/null 2>&1

# Import into the login keychain, pre-authorizing codesign to use the key.
security import "$TMP/cert.p12" -k "$KEYCHAIN" -P "" \
  -T /usr/bin/codesign -T /usr/bin/security >/dev/null 2>&1

echo "✓ Certificate installed in your login keychain."
echo
echo "  Next steps:"
echo "    1. ./build-app.sh"
echo "    2. The FIRST time codesign uses the key, macOS shows a keychain"
echo "       dialog — click \"Always Allow\" so future builds are silent."
echo "    3. Grant Screen Recording once more (this grant now persists)."
