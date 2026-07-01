#!/bin/bash
# Produces the distributable release artifacts for SnapCraft:
#   dist/SnapCraft-<version>.dmg   -> drag-to-Applications installer (download)
#   dist/SnapCraft-<version>.zip   -> Sparkle update archive
#   dist/appcast.xml               -> Sparkle update feed (EdDSA-signed)
#
# You then upload all three to a GitHub Release tagged v<version>. The source
# code is NOT published — only these files are.
#
# Prerequisites (one-time): run `scripts/release.sh --keygen` to create the
# Sparkle EdDSA key pair, then paste the printed public key into
# Resources/Info.plist (SUPublicEDKey). See docs/RELEASING.md.
#
# Usage:
#   scripts/release.sh            build + package + sign
#   scripts/release.sh --keygen   generate the Sparkle signing key (first time)
set -euo pipefail

# ---- Configure these two for your GitHub account / release repo -------------
GITHUB_OWNER="${GITHUB_OWNER:-mei-somei}"
GITHUB_REPO="${GITHUB_REPO:-snapcraft}"
# ----------------------------------------------------------------------------

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="SnapCraft"
APP="$ROOT/$APP_NAME.app"
DIST="$ROOT/dist"

SPARKLE_BIN="$(find "$ROOT/.build/artifacts" -type d -name bin -path '*sparkle*' 2>/dev/null | head -1)"
if [[ -z "$SPARKLE_BIN" ]]; then
  echo "✗ Sparkle tools not found. Run 'swift package resolve' first." >&2
  exit 1
fi

# --- First-time key generation ----------------------------------------------
if [[ "${1:-}" == "--keygen" ]]; then
  echo "▸ Generating Sparkle EdDSA key pair (private key stored in your Keychain)…"
  "$SPARKLE_BIN/generate_keys"
  echo
  echo "Copy the public key above into Resources/Info.plist → SUPublicEDKey."
  exit 0
fi

if [[ "$GITHUB_OWNER" == "OWNER" || "$GITHUB_REPO" == "REPO" ]]; then
  echo "✗ Set GITHUB_OWNER and GITHUB_REPO at the top of this script (or via env)." >&2
  exit 1
fi

# --- Version from Info.plist ------------------------------------------------
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
TAG="v$VERSION"
echo "▸ Releasing $APP_NAME $VERSION (tag $TAG)"

# --- Build the signed .app --------------------------------------------------
"$ROOT/build-app.sh" release

# --- Fresh dist dir (single-version appcast; see docs/RELEASING.md) ----------
rm -rf "$DIST"
mkdir -p "$DIST"

# --- Sparkle update archive (zip preserving symlinks/permissions) -----------
# The zip is generated inside an isolated folder that generate_appcast scans.
# generate_appcast errors if a folder holds two archives for the same version,
# so the DMG (a human-download asset) is kept OUT of this folder.
APPCAST_DIR="$DIST/.appcast"
mkdir -p "$APPCAST_DIR"
ZIP="$APPCAST_DIR/$APP_NAME-$VERSION.zip"
echo "▸ Creating update archive ${ZIP}…"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

# --- DMG installer (with /Applications shortcut) ----------------------------
DMG="$DIST/$APP_NAME-$VERSION.dmg"
echo "▸ Creating DMG ${DMG}…"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

# --- Generate the signed appcast --------------------------------------------
# generate_appcast scans the appcast folder (zip only), signs it with the
# Keychain EdDSA private key, and writes appcast.xml. download-url-prefix points
# at this release's GitHub assets (tag-specific) so URLs resolve to your uploads.
echo "▸ Generating signed appcast.xml…"
"$SPARKLE_BIN/generate_appcast" \
  --download-url-prefix "https://github.com/$GITHUB_OWNER/$GITHUB_REPO/releases/download/$TAG/" \
  "$APPCAST_DIR"

# Flatten the artifacts into $DIST for upload (zip + appcast.xml alongside dmg).
mv "$ZIP" "$DIST/"
mv "$APPCAST_DIR/appcast.xml" "$DIST/"
ZIP="$DIST/$APP_NAME-$VERSION.zip"
rm -rf "$APPCAST_DIR"

echo
echo "✓ Artifacts ready in $DIST:"
ls -1 "$DIST"
echo
echo "Next: create the GitHub release and upload all of the above, e.g.:"
echo "  gh release create $TAG \"$DMG\" \"$ZIP\" \"$DIST/appcast.xml\" \\"
echo "    --repo $GITHUB_OWNER/$GITHUB_REPO --title \"$APP_NAME $VERSION\" --notes \"…\""
