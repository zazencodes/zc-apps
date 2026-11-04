#!/usr/bin/env bash
# Builds build/Facecam.app.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/build/Facecam.app"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
swiftc -O "$root/mac/main.swift" -o "$app/Contents/MacOS/Facecam"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Facecam</string>
  <key>CFBundleIdentifier</key><string>com.zazencodes.facecam</string>
  <key>CFBundleExecutable</key><string>Facecam</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSCameraUsageDescription</key><string>Facecam shows your webcam in a floating window.</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$app"
echo "Built $app"
