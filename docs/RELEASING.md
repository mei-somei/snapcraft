# Releasing SnapCraft

How to cut a release and publish it so users can install via Homebrew or DMG and
get in-app auto-updates. **Only release files are published — the source stays
private.**

## Overview of the moving parts

| Piece | Where it lives | Purpose |
|-------|----------------|---------|
| `SnapCraft-<v>.dmg` | GitHub Release asset | Manual download / Homebrew cask source |
| `SnapCraft-<v>.zip` | GitHub Release asset | Sparkle update archive |
| `appcast.xml` | GitHub Release asset | Sparkle update feed (EdDSA-signed) |
| `Casks/snapcraft.rb` | Homebrew **tap** repo | `brew install` formula |
| Sparkle keys | your **Keychain** | Sign updates (public key baked into the app) |

You need **two GitHub repos** (both public, both source-free):
1. **Release repo** — `mei-somei/snapcraft` — holds `README.md` + the release
   assets (DMG, zip, appcast.xml).
2. **Tap repo** — `mei-somei/homebrew-tap` — holds `Casks/snapcraft.rb`. The
   `homebrew-` prefix is required; it enables `brew install mei-somei/tap/snapcraft`.

---

## One-time setup

### 1. Generate the Sparkle signing key

```sh
scripts/release.sh --keygen
```

This stores the **private** key in your login Keychain and prints the **public**
key. Paste the public key into `Resources/Info.plist` → `SUPublicEDKey`.
**Never commit or share the private key.**

### 2. Fill in the placeholders

- `Resources/Info.plist` → `SUPublicEDKey`: the public key from step 1.
  (`SUFeedURL` is already set to `mei-somei/snapcraft`.)
- `release-repo/Casks/snapcraft.rb` → only the `sha256` per release (repo/tap
  names already filled in).

Everything else (`SUFeedURL`, cask URLs, README links, `scripts/release.sh`
owner/repo) is already pointed at `mei-somei/snapcraft` and `mei-somei/tap`.

### 3. (Optional) install the stable self-signed cert

```sh
./create-signing-cert.sh
```

Keeps the Screen Recording permission grant stable across local rebuilds. Not
required for distribution (releases are signed ad-hoc + Sparkle-EdDSA).

---

## Cutting a release

### 1. Bump the version

Edit **both** `CFBundleShortVersionString` and `CFBundleVersion` in
`Resources/Info.plist` (e.g. `2.4.0` → `2.5.0`). Sparkle compares
`CFBundleVersion` to decide whether an update is newer, so it must increase.

### 2. Build + package + sign

```sh
scripts/release.sh
```

(Owner/repo are pre-set to `mei-somei/snapcraft`; override with `GITHUB_OWNER` /
`GITHUB_REPO` env vars if needed.) This produces in `dist/`:
- `SnapCraft-<v>.dmg`
- `SnapCraft-<v>.zip`
- `appcast.xml` (signed)

### 3. Publish the GitHub Release

```sh
gh release create v<version> \
  dist/SnapCraft-<version>.dmg \
  dist/SnapCraft-<version>.zip \
  dist/appcast.xml \
  --repo mei-somei/snapcraft \
  --title "SnapCraft <version>" \
  --notes "What changed in this release…"
```

The release notes you write here are what Sparkle shows users in the update
dialog (it reads the appcast description / links).

### 4. Update the Homebrew cask

```sh
shasum -a 256 dist/SnapCraft-<version>.dmg   # copy the hash
```

In your **tap** repo, edit `Casks/snapcraft.rb`: bump `version` and paste the
new `sha256`, then commit & push. Done.

---

## How auto-update works (sanity model)

1. App reads `SUFeedURL` → downloads `appcast.xml`.
2. Compares the appcast's `sparkle:version` to its own `CFBundleVersion`.
3. If newer, downloads `SnapCraft-<v>.zip`, verifies the **EdDSA signature**
   against the embedded `SUPublicEDKey`, strips quarantine, and swaps the app.
4. No Gatekeeper prompt — the signature check replaces notarization trust.

This is why the first install is the only time users see a Gatekeeper warning.

---

## Notes & gotchas

- **Single-version appcast:** `scripts/release.sh` wipes `dist/` each run, so the
  generated `appcast.xml` lists only the current version. That's fine for
  Sparkle. If you want a full version history in the feed, keep older archives in
  `dist/` and re-run `generate_appcast` (and use per-tag download URLs).
- **`CFBundleVersion` must monotonically increase** or Sparkle won't offer the
  update.
- **Private key loss:** if you lose the Sparkle private key, existing users can't
  validate new updates — you'd have to ship a new public key via a fresh manual
  install. Back it up (it's in Keychain under "Private key for signing SnapCraft
  updates" / `ed25519`).
- **Notarization later:** if you get an Apple Developer ID, add a notarize +
  staple step to `build-app.sh` and the first-launch Gatekeeper bypass goes away.
