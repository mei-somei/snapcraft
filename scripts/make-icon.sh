#!/bin/bash
# Generates Resources/AppIcon.icns (the app's Finder/Applications icon) from a
# single square source image. Apple wants a 1024x1024 PNG; smaller works but
# looks soft. After running this, rebuild with ./build-app.sh release.
#
# Usage: scripts/make-icon.sh path/to/icon-1024.png
set -euo pipefail

SRC="${1:-}"
if [[ -z "$SRC" || ! -f "$SRC" ]]; then
  echo "Usage: scripts/make-icon.sh path/to/icon-1024.png" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"

# Standard macOS icon sizes (1x + 2x retina variants).
for size in 16 32 128 256 512; do
  sips -z "$size" "$size"         "$SRC" --out "$ICONSET/icon_${size}x${size}.png"   >/dev/null
  sips -z $((size*2)) $((size*2)) "$SRC" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$ROOT/Resources/AppIcon.icns"
rm -rf "$(dirname "$ICONSET")"

echo "✓ Wrote Resources/AppIcon.icns"
echo "  Now rebuild:  ./build-app.sh release   (or scripts/release.sh for a full release)"
