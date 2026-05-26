# Project Instructions

## Product Identity

- Product name: `Cuneiform`.
- Bundle identifier: `io.damao.cuneiform`.
- Keep Swift target, module, source directory, and test directory names as `SimpleMarkdownPreviewerApp`, `SimpleMarkdownPreviewerCore`, and `SimpleMarkdownPreviewerCoreTests` unless the user explicitly asks for a structural rename.

## Language

- User-facing app copy and product documentation should be Chinese by default when written for the user.
- Technical documentation, code symbols, comments, scripts, and commit messages should be English.

## Verification

- Run `./scripts/check.sh` before declaring code or release-script changes complete.
- `./scripts/check.sh` covers Swift tests, Swift build, app bundle construction, bundle metadata verification, and DMG packaging checks.
- Do not commit `.build/` artifacts.

## Build And Release

- Development app bundle:

```bash
./scripts/build_app.sh
```

- Output:

```bash
.build/app/Cuneiform.app
```

- `scripts/build_app.sh` signs the bundle adhoc for local verification. Public distribution must be rebuilt, Developer ID signed, notarized, stapled, verified with Gatekeeper, and then packaged as a DMG.
- Developer ID identity:

```text
Developer ID Application: Guan Xiaoyu (T7976FL2LP)
```

- Notary profile:

```text
cuneiform-notary
```

- Final DMG packaging:

```bash
./scripts/package_dmg.sh
```

- Output:

```bash
.build/release/Cuneiform.dmg
```

## Assets

- `Resources/Cuneiform.png` is the 1024x1024 transparent source icon.
- `Resources/Cuneiform.icns` is the committed bundle icon used by `scripts/build_app.sh`.
- If the icon source changes, regenerate `Resources/Cuneiform.icns`, rerun `./scripts/check.sh`, then redo Developer ID signing and notarization for release artifacts.

## Signing Notes

- Sandbox-limited `codesign --verify` may fail to see the Developer ID certificate chain. When validating Developer ID signatures, run the verification command outside the sandbox.
- Expected release checks:

```bash
codesign --verify --deep --strict --verbose=2 .build/app/Cuneiform.app
xcrun stapler validate .build/app/Cuneiform.app
spctl -a -vvv -t exec .build/app/Cuneiform.app
```
