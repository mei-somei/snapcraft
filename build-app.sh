#!/bin/bash
# Builds the SnapCraft SwiftPM executable and wraps it into a runnable, ad-hoc
# signed macOS .app bundle. A real bundle (with Info.plist + signature) is
# required for the Screen Recording TCC permission and for LSUIElement to take
# effect. It also embeds Sparkle.framework so the in-app auto-update flow works.
# Usage: ./build-app.sh [debug|release]
set -euo pipefail

CONFIG="${1:-debug}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="SnapCraft"
APP="$ROOT/$APP_NAME.app"

echo "▸ Building ($CONFIG)…"
swift build -c "$CONFIG"

BIN="$(swift build -c "$CONFIG" --show-bin-path)/$APP_NAME"
if [[ ! -f "$BIN" ]]; then
  echo "✗ Build product not found at $BIN" >&2
  exit 1
fi

echo "▸ Assembling $APP_NAME.app…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# App icon (Finder/Applications thumbnail). Generate it with scripts/make-icon.sh.
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
else
  echo "  (no Resources/AppIcon.icns — app will use the generic icon; run scripts/make-icon.sh)"
fi

# --- Embed Sparkle.framework -------------------------------------------------
# SwiftPM links against Sparkle's XCFramework but does not embed it. The .app
# binary has an @executable_path/../Frameworks rpath (see Package.swift), so we
# copy the matching macOS slice into Contents/Frameworks here.
echo "▸ Embedding Sparkle.framework…"
SPARKLE_XC="$(find "$ROOT/.build/artifacts" -type d -name 'Sparkle.xcframework' 2>/dev/null | head -1)"
if [[ -z "$SPARKLE_XC" ]]; then
  echo "✗ Sparkle.xcframework not found under .build/artifacts. Run 'swift package resolve' first." >&2
  exit 1
fi
# Pick the macOS slice (its directory name starts with 'macos-').
SPARKLE_SLICE="$(find "$SPARKLE_XC" -maxdepth 2 -type d -name 'Sparkle.framework' -path '*macos*' | head -1)"
if [[ -z "$SPARKLE_SLICE" ]]; then
  echo "✗ macOS slice of Sparkle.framework not found in $SPARKLE_XC" >&2
  exit 1
fi
cp -R "$SPARKLE_SLICE" "$APP/Contents/Frameworks/"

# --- Code signing ------------------------------------------------------------
# Sign with the stable self-signed identity if present, so the Screen Recording
# (TCC) grant survives rebuilds. Falls back to ad-hoc, which re-prompts every
# rebuild because TCC then anchors to the changing CDHash.
# Run ./create-signing-cert.sh once to install the identity.
IDENTITY="SnapCraft Self-Signed"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
  SIGN_AS="$IDENTITY"
  echo "▸ Signing (\"$IDENTITY\")…"
else
  SIGN_AS="-"
  echo "▸ Signing (ad-hoc — run ./create-signing-cert.sh to stop re-prompts)…"
fi

# Sparkle ships helper executables (Autoupdate, Updater.app, XPC services) that
# must be signed before (and separately from) the outer bundle. Sign the
# framework's nested code first, then the framework, then the app. Using --deep
# on the final app picks up anything nested we did not enumerate.
SPARKLE_FW="$APP/Contents/Frameworks/Sparkle.framework"
codesign --force --sign "$SIGN_AS" --timestamp=none \
  "$SPARKLE_FW/Versions/Current/Autoupdate" \
  "$SPARKLE_FW/Versions/Current/Updater.app" 2>/dev/null || true
codesign --force --deep --sign "$SIGN_AS" --timestamp=none "$SPARKLE_FW" 2>/dev/null \
  || echo "  (Sparkle framework signing skipped)"
codesign --force --deep --sign "$SIGN_AS" --timestamp=none "$APP" 2>/dev/null \
  || echo "  (app signing skipped — running unsigned)"

echo "✓ Built $APP"
echo "  Run with:  open \"$APP\"   (or: \"$APP/Contents/MacOS/$APP_NAME\" for console logs)"
