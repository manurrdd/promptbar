#!/bin/zsh
# Builds Promptbar.app (native bundle) from a release build.
set -e
cd "$(dirname "$0")"

swift build -c release

APP="Promptbar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp .build/release/Promptbar "$APP/Contents/MacOS/Promptbar"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Promptbar</string>
    <key>CFBundleIdentifier</key><string>local.promptbar</string>
    <key>CFBundleName</key><string>Promptbar</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Done: $APP  (move it to /Applications if you like)"
