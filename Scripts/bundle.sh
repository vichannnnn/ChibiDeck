#!/bin/bash
# Builds, assembles and signs "build/Chibi Deck.app" (spec 2026-09-07 Plan 3 §10.2).
#   IDENTITY="Apple Development: …" VERSION=1.1.0 Scripts/bundle.sh
#   Also writes build/ChibiDeck-<version>.zip, the file to attach to a GitHub release.
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${IDENTITY:--}"          # ad-hoc unless set; `security find-identity -v -p codesigning` lists yours
VERSION="${VERSION:-1.1.0}"
BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo 1)
APP="build/Chibi Deck.app"          # the bundle carries the display name; the executable inside stays ChibiDeck
RESOURCE_BUNDLE=ChibiDeck_PanelCore.bundle

# Swift 6.3.3: cross-module optimisation crashes swift-frontend on this package (DESERIALIZATION FAILURE while SILCombine
# inlines PanelCore.TouchRegion.== — its CoreFoundation.CGPoint.x cross-reference cannot be resolved from the app target,
# which sees CGPoint through CoreGraphics). CMO is not needed for this app; drop the flag when the toolchain is fixed.
# The binary must not carry this Mac's paths: SwiftPM bakes the scratch path into the resource-bundle accessor, so it
# lives under /private/tmp rather than the checkout, and the sources use no `#filePath` (checked below).
SCRATCH="${SCRATCH:-/private/tmp/chibideck-build}"
BUILD=(swift build -c release --scratch-path "$SCRATCH" -Xswiftc -disable-cmo)
"${BUILD[@]}"
BIN=$("${BUILD[@]}" --show-bin-path)
[ -x "$BIN/ChibiDeck" ] || { echo "no executable at $BIN/ChibiDeck" >&2; exit 2; }
[ -d "$BIN/$RESOURCE_BUNDLE" ] || { echo "no resource bundle at $BIN/$RESOURCE_BUNDLE" >&2; exit 2; }
if strings "$BIN/ChibiDeck" | grep -q -E "^/Users/|$PWD|$HOME"; then
	echo "the binary embeds a path from this Mac (a #filePath or a scratch dir under the checkout?):" >&2
	strings "$BIN/ChibiDeck" | grep -E "^/Users/|$PWD|$HOME" >&2
	exit 2
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Scripts"
cp "$BIN/ChibiDeck" "$APP/Contents/MacOS/ChibiDeck"
cp -R "$BIN/$RESOURCE_BUNDLE" "$APP/Contents/Resources/$RESOURCE_BUNDLE"
cp Scripts/install-statusline.sh "$APP/Contents/Resources/Scripts/install-statusline.sh"
chmod +x "$APP/Contents/Resources/Scripts/install-statusline.sh"
cp Resources/ChibiDeck.icns "$APP/Contents/Resources/ChibiDeck.icns"   # Scripts/icon/make-icon.py
printf 'APPL????' > "$APP/Contents/PkgInfo"

# macOS 26 shows a plain .icns shrunk inside a grey glass tile; it wants an Icon Composer icon compiled into Assets.car
# (CFBundleIconName). actool ships with Xcode, not the command-line tools, so without it the app keeps the .icns only.
# Absolute paths: actool's ibtoold helper is a long-lived daemon that resolves relative paths against its own cwd.
ICON_NAME_KEYS=""
if ACTOOL=$(xcrun --find actool 2>/dev/null) && [ -d Resources/ChibiDeck.icon ]; then
	ACOUT=$(mktemp -d)
	"$ACTOOL" "$PWD/Resources/ChibiDeck.icon" --compile "$ACOUT" --platform macosx --minimum-deployment-target 15.0 \
		--app-icon ChibiDeck --include-all-app-icons --output-partial-info-plist "$ACOUT/partial.plist" \
		--output-format human-readable-text --errors --warnings >/dev/null
	cp "$ACOUT/Assets.car" "$APP/Contents/Resources/Assets.car"
	rm -rf "$ACOUT"
	ICON_NAME_KEYS=$'\t<key>CFBundleIconName</key>\n\t<string>ChibiDeck</string>'
	echo "compiled Resources/ChibiDeck.icon into Assets.car"
else
	echo "actool not found (needs Xcode); the app carries the .icns only, which macOS 26 shows shrunk" >&2
fi

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>
	<string>me.himaa.chibideck</string>
	<key>CFBundleName</key>
	<string>Chibi Deck</string>
	<key>CFBundleDisplayName</key>
	<string>Chibi Deck</string>
	<key>CFBundleExecutable</key>
	<string>ChibiDeck</string>
	<key>CFBundleIconFile</key>
	<string>ChibiDeck</string>
$ICON_NAME_KEYS
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>$BUILD_NUMBER</string>
	<key>LSMinimumSystemVersion</key>
	<string>15.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSAppleEventsUsageDescription</key>
	<string>Chibi Deck selects the Terminal tab of a Claude Code session and types your Continue text into it.</string>
	<key>NSHumanReadableCopyright</key>
	<string>Local build. No network access.</string>
</dict>
</plist>
EOF

plutil -lint "$APP/Contents/Info.plist"
# The SwiftPM resource bundle holds no code and no Info.plist, so `codesign` refuses it as a bundle
# ("bundle format unrecognized"); signing the app seals it into _CodeSignature/CodeResources instead.
codesign --force --options runtime --entitlements Scripts/ChibiDeck.entitlements --sign "$IDENTITY" "$APP"
codesign --verify --strict --deep --verbose=2 "$APP"
ZIP="build/ChibiDeck-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"       # preserves the signature and resource forks, unlike zip(1)
echo "built $APP ($VERSION build $BUILD_NUMBER), signed as: $IDENTITY"
echo "release archive: $ZIP"
