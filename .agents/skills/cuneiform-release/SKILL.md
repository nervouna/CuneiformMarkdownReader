---
name: cuneiform-release
description: Use when creating, verifying, notarizing, packaging, or publishing a Cuneiform macOS release to GitHub from this workspace.
---

# Cuneiform Release

Use this skill for release tasks in `/Users/damao/Develop/Projects/SimpleMarkdownPreviewer`.

## Preconditions

- Work from `main`.
- Ensure `git status --short --branch` is clean and aligned with `origin/main`.
- Do not commit `.build/` artifacts.
- Release version format: `vX.Y.Z`.
- GitHub repo: `nervouna/CuneiformMarkdownReader`.

## Local Verification

Run the full local gate before release packaging:

```bash
./scripts/check.sh
```

This covers Swift tests, Swift build, app bundle construction, bundle metadata verification, and DMG packaging checks.

## Build And Sign

Build the app bundle:

```bash
./scripts/build_app.sh
```

`scripts/build_app.sh` produces an adhoc-signed development app at:

```bash
.build/app/Cuneiform.app
```

For release, replace the adhoc signature with Developer ID:

```bash
codesign --force \
  --deep \
  --timestamp \
  --options runtime \
  --sign "Developer ID Application: Guan Xiaoyu (T7976FL2LP)" \
  .build/app/Cuneiform.app
```

Verify outside the sandbox when possible, because sandbox-limited `codesign` may not see the Developer ID certificate chain:

```bash
codesign --verify --deep --strict --verbose=2 .build/app/Cuneiform.app
```

## Notarize And Staple

Create a zip for notarization:

```bash
ditto -c -k --keepParent .build/app/Cuneiform.app .build/app/Cuneiform.zip
```

Submit to Apple:

```bash
xcrun notarytool submit .build/app/Cuneiform.zip \
  --keychain-profile cuneiform-notary \
  --wait
```

Only continue if status is `Accepted`.

Staple the ticket:

```bash
xcrun stapler staple .build/app/Cuneiform.app
```

Run release validation:

```bash
xcrun stapler validate .build/app/Cuneiform.app
spctl -a -vvv -t exec .build/app/Cuneiform.app
```

Expected Gatekeeper source:

```text
source=Notarized Developer ID
origin=Developer ID Application: Guan Xiaoyu (T7976FL2LP)
```

## Package DMG

Package after notarization and stapling:

```bash
./scripts/package_dmg.sh --output .build/release/Cuneiform-VERSION.dmg
```

Replace `VERSION` with the release tag, for example:

```bash
./scripts/package_dmg.sh --output .build/release/Cuneiform-v0.1.0.dmg
```

Verify the DMG structure by mounting it and checking:

- `Cuneiform.app` exists.
- `Applications` is a symlink to `/Applications`.

Compute the checksum:

```bash
shasum -a 256 .build/release/Cuneiform-VERSION.dmg
```

## GitHub Release

Confirm the release does not already exist:

```bash
gh release view VERSION --repo nervouna/CuneiformMarkdownReader
```

Create the release:

```bash
gh release create VERSION .build/release/Cuneiform-VERSION.dmg \
  --repo nervouna/CuneiformMarkdownReader \
  --target main \
  --title "Cuneiform VERSION" \
  --notes-file /tmp/cuneiform-release-notes.md
```

Release notes should include:

- One-line product summary.
- Main highlights.
- State that the DMG is Developer ID signed and Apple notarized.
- SHA-256 for the uploaded DMG.

After creation, verify:

```bash
gh release view VERSION --repo nervouna/CuneiformMarkdownReader
```
