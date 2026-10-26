#!/usr/bin/env bash
# Builds build/CPU Bars.app.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/build/CPU Bars.app"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
swiftc -O -parse-as-library "$root/mac/main.swift" -o "$app/Contents/MacOS/CPUBars"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>CPU Bars</string>
  <key>CFBundleIdentifier</key><string>com.zazencodes.cpubars</string>
  <key>CFBundleExecutable</key><string>CPUBars</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$app"
echo "Built $app"
