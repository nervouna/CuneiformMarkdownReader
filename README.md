# Cuneiform

Cuneiform is a minimal macOS Markdown previewer for quickly reading long Markdown documents, especially AI-generated notes and drafts.

## Features

- Renders `.md` and `.markdown` files as preview-only content.
- Opens files from Finder, drag and drop, command-line file arguments, and the native file picker.
- Can set itself as the default Markdown viewer from the app menu.
- Uses native macOS windowing, menus, document type metadata, and a bundled app icon.

## Install

Use the DMG release artifact:

```bash
.build/release/Cuneiform.dmg
```

Open the DMG and drag `Cuneiform.app` to `Applications`.

## Development

Run the full local gate before considering changes complete:

```bash
./scripts/check.sh
```

Build the app bundle:

```bash
./scripts/build_app.sh
```

The development app bundle is written to:

```bash
.build/app/Cuneiform.app
```

### Renderer fallback

Cuneiform uses the native Markdown renderer by default. To compare or debug the legacy WebView renderer from Terminal:

```bash
CUNEIFORM_RENDERER=webview /Applications/Cuneiform.app/Contents/MacOS/Cuneiform path/to/file.md
```

### Startup measurement

Measure startup against the installed app bundle opened through LaunchServices:

```bash
CUNEIFORM_RENDERER=native CUNEIFORM_APP=/Applications/Cuneiform.app ITERATIONS=10 ./scripts/measure_startup.sh path/to/file.md
CUNEIFORM_RENDERER=webview CUNEIFORM_APP=/Applications/Cuneiform.app ITERATIONS=10 ./scripts/measure_startup.sh path/to/file.md
```

Before treating measurements as product evidence, rebuild with `./scripts/check.sh`, install `.build/app/Cuneiform.app` to `/Applications/Cuneiform.app`, verify the default Markdown viewer, and confirm the installed bundle matches `.build/app`.

## Release

`scripts/build_app.sh` produces an adhoc-signed development bundle. For public distribution, rebuild, sign with Developer ID, notarize, staple, then package the DMG:

```bash
./scripts/build_app.sh

codesign --force \
  --deep \
  --timestamp \
  --options runtime \
  --sign "Developer ID Application: Guan Xiaoyu (T7976FL2LP)" \
  .build/app/Cuneiform.app

ditto -c -k --keepParent .build/app/Cuneiform.app .build/app/Cuneiform.zip

xcrun notarytool submit .build/app/Cuneiform.zip \
  --keychain-profile cuneiform-notary \
  --wait

xcrun stapler staple .build/app/Cuneiform.app

codesign --verify --deep --strict --verbose=2 .build/app/Cuneiform.app
xcrun stapler validate .build/app/Cuneiform.app
spctl -a -vvv -t exec .build/app/Cuneiform.app

./scripts/package_dmg.sh
```

The release DMG is written to:

```bash
.build/release/Cuneiform.dmg
```

## Project Notes

- Product name: `Cuneiform`
- Bundle identifier: `io.damao.cuneiform`
- Swift target/module names intentionally remain `SimpleMarkdownPreviewerApp` and `SimpleMarkdownPreviewerCore`.
- Icon source: `Resources/Cuneiform.png`
- Bundle icon: `Resources/Cuneiform.icns`

## License

WTFPL. See `LICENSE`.
