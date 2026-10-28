#!/usr/bin/env bash
# Builds build/Record Mode.app.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/build/Record Mode.app"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
swiftc -O -parse-as-library "$root/mac/main.swift" -o "$app/Contents/MacOS/RecordMode"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Record Mode</string>
  <key>CFBundleIdentifier</key><string>com.zazencodes.recordmode</string>
  <key>CFBundleExecutable</key><string>RecordMode</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$app"
echo "Built $app"
