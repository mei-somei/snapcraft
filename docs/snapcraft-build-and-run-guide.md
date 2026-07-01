# SnapCraft — Build & Run Guide

Native macOS screenshot capture + annotation app. SwiftUI / AppKit, built from
the `SnapCraft App.dc.html` design handoff. Menu-bar resident (`LSUIElement`),
~5 MB, real `ScreenCaptureKit` capture and Vision OCR.

## Requirements
- macOS 14+ (built/tested on macOS 26, Xcode 26 / Swift 6.3)
- Xcode command-line tools (`xcode-select -p`)

## Build & run
```bash
./build-app.sh          # debug build → SnapCraft.app (ad-hoc signed)
open SnapCraft.app      # launches into the menu bar (no Dock icon)
```
`./build-app.sh release` for an optimized build. For console logs run the binary
directly: `./SnapCraft.app/Contents/MacOS/SnapCraft`.

### First launch
- A **camera icon** appears in the menu bar. Click it for the capture menu.
- macOS will prompt for **Screen Recording** permission on the first capture
  (System Settings → Privacy & Security → Screen Recording). Approve, then
  relaunch. This is required by `ScreenCaptureKit`.

## Using it
- **⌘⇧4** drag-select a region · **⌘⇧5** pick a window · **⌘⇧3** fullscreen ·
  **⌘⇧P** pin the last capture. All rebindable in Settings → Shortcuts.
- After capture the **Editor** opens: pick a tool from the left strip, set
  color/stroke in the top bar, draw on the image. **Copy** (accent button, ⌘C),
  **Save** (⌘S, to `~/Pictures/SnapCraft`), or **Pin** to float it on screen.
- Tools: select, crop, shape, arrow, line, pen, highlighter, text, numbered
  step, blur/redact, OCR (drag a region → extracted text goes to the clipboard).
- ⌘Z / ⌘⇧Z undo/redo; ⌫ deletes the selected annotation.

## Verifying the UI without a live capture
```bash
./SnapCraft.app/Contents/MacOS/SnapCraft --render-previews ./previews
```
Renders `editor.png`, `canvas.png`, `composite.png`, `settings.png`,
`settings-content.png` from a synthetic capture — the fastest way to eyeball
pixel fidelity. (`ImageRenderer` can't snapshot `ScrollView`/`Menu`, so the
editor/settings *chrome* and the *content* are rendered separately; both are
correct live.)

## Architecture
```
Sources/SnapCraft/
  App/         main.swift, SnapCraftApp (MenuBarExtra), AppController (coordinator),
               WindowManager, PinView, PreviewRenderer
  Capture/     ScreenCaptureService (ScreenCaptureKit), RegionSelectionOverlay
               (drag-select / window-pick), HotKeyManager (Carbon global hot keys),
               CaptureController (orchestration), OCRService (Vision)
  Editor/      EditorViewModel (annotations + undo/redo), EditorView, CanvasView
               (interaction), AnnotationLayer (shared renderer), DotGridView, Toolbars/
  Settings/    SettingsView, SettingsSections, SettingsComponents, ShortcutRecorder
  Export/      Exporter (composite → clipboard / file / pin)
  Models/      Tool, Annotation, AccentPalette, KeyCombo, AppSettings, CapturedImage
  Theme/       Theme (design tokens — single source for colors/type/radii/accent)
```
Annotation geometry is stored in image-point space, so the live canvas and the
`Exporter` composite (used for copy/save/pin) share one renderer and stay
resolution-independent.

## Notes / known stubs
- **Launch at login** and **Show in menu bar** toggles persist but are not yet
  wired to `SMAppService` / status-item teardown.
- Keycaps display in canonical macOS modifier order (`⇧⌘4`) rather than the
  mock's `⌘⇧4`.
- Region selection covers the screen under the cursor (single display).
