#!/bin/sh
set -eu
cd "$(dirname "$0")"

VERSION=${VERSION:-1.0.0}
case "$VERSION" in
    ''|*[!0-9.]*|.*|*.|*..*) printf '%s\n' 'VERSION must be a dotted numeric version.' >&2; exit 1 ;;
esac
ICON="$PWD/assets/AppIcon.icns"
[ -f "$ICON" ] || { printf '%s\n' 'Missing assets/AppIcon.icns.' >&2; exit 1; }
APP="$PWD/build/stopwatch.app"
BUILD_TMP=$(mktemp -d "${TMPDIR:-/tmp}/dumb-clock-build.XXXXXX")
trap 'rm -rf "$BUILD_TMP"' EXIT HUP INT TERM
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

for ARCH in arm64 x86_64; do
    xcrun swiftc -swift-version 6 -O -target "$ARCH-apple-macos13.0" -framework AppKit \
        Stopwatch.swift DialView.swift DurationInput.swift main.swift -o "$BUILD_TMP/Stopwatch-$ARCH"
done
xcrun lipo -create "$BUILD_TMP/Stopwatch-arm64" "$BUILD_TMP/Stopwatch-x86_64" \
    -output "$APP/Contents/MacOS/Stopwatch"
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Stopwatch</string>
<key>CFBundleIdentifier</key><string>com.gregoryli.stopwatch</string>
<key>CFBundleName</key><string>stopwatch</string>
<key>CFBundleDisplayName</key><string>stopwatch</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>Copyright © 2026 Gregory Li. MIT License.</string>
</dict></plist>
PLIST
plutil -lint "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
printf '%s\n' "$APP"
