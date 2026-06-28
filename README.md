# SnapCraft

A lightweight macOS **menu-bar** app for capturing, annotating, and OCR-ing
screenshots. Lives in your menu bar — no Dock icon, global hot keys, instant
editor.

> Requires **macOS 14 (Sonoma) or later**.

---

## Install

1. Download **`SnapCraft-<version>.dmg`** from the
   [latest release](https://github.com/mei-somei/snapcraft/releases/latest).
2. Open the DMG and drag **SnapCraft** into **Applications**.
3. **First launch:** right-click `SnapCraft.app` → **Open** → **Open** (this is
   needed once because the app isn't notarized by Apple). After that it opens
   normally.

   If you still see *"SnapCraft is damaged"*, clear the quarantine flag:

   ```sh
   xattr -dr com.apple.quarantine /Applications/SnapCraft.app
   ```

### Grant Screen Recording permission

On first capture, macOS asks for **Screen Recording** access:
**System Settings → Privacy & Security → Screen Recording → enable SnapCraft**,
then relaunch the app.

---

## Updating

SnapCraft updates itself. Click the menu-bar icon → **Check for Updates…**, or
let it check automatically in the background. Updates install cleanly without
the Gatekeeper prompt you saw on first install.

---

## Uninstall

Delete `/Applications/SnapCraft.app`.

---

*SnapCraft is distributed as a notarization-free build. The first launch
requires a one-time Gatekeeper bypass; all subsequent in-app updates are
signed and verified with Sparkle's EdDSA signatures.*
