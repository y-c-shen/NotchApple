#!/bin/bash
# Build a distributable NotchApple.app (and .zip) into dist/.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="dist/NotchApple.app"
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/NotchApple "$APP/Contents/MacOS/NotchApple"
cp -R .build/release/NotchApple_NotchApple.bundle "$APP/Contents/Resources/"
cp Packaging/AppIcon.icns "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>NotchApple</string>
    <key>CFBundleIdentifier</key><string>com.charles.notchapple</string>
    <key>CFBundleName</key><string>Notch Apple</string>
    <key>CFBundleDisplayName</key><string>Notch Apple</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSAppleEventsUsageDescription</key><string>Notch Apple checks your browser's current tab so the Distraction Blocker can redirect blocked sites.</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
ditto -c -k --keepParent "$APP" dist/NotchApple.zip

echo "Built: $APP"
echo "Zip:   dist/NotchApple.zip"
