#!/usr/bin/env bash
# Builds build/Pretty Draw.app.
#
# Signs with a real Apple Development identity when there is one, so launch at login keeps recognising the app across
# rebuilds. Set PRETTY_DRAW_SIGN_IDENTITY=- to sign ad hoc.
set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
app="$root/build/Pretty Draw.app"
identity="${PRETTY_DRAW_SIGN_IDENTITY:-Apple Development}"
version="$(cat "$root/VERSION")"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "VERSION must contain X.Y.Z" >&2
    exit 1
fi

cd "$root"
swift build -c release --product PrettyDraw
swift build -c release --product pretty-draw-render
bin="$(swift build -c release --show-bin-path)"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin/PrettyDraw" "$app/Contents/MacOS/PrettyDraw"

iconset="$(mktemp -d)/PrettyDraw.iconset"
"$bin/pretty-draw-render" icon "$iconset"
iconutil -c icns "$iconset" -o "$app/Contents/Resources/PrettyDraw.icns"
rm -rf "$(dirname "$iconset")"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Pretty Draw</string>
  <key>CFBundleDisplayName</key><string>Pretty Draw</string>
  <key>CFBundleIdentifier</key><string>com.zazencodes.prettydraw</string>
  <key>CFBundleExecutable</key><string>PrettyDraw</string>
  <key>CFBundleIconFile</key><string>PrettyDraw</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$version</string>
  <key>CFBundleVersion</key><string>$version</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>ZazenCodes</string>
</dict>
</plist>
PLIST

codesign --force --timestamp=none --sign "$identity" "$app"
echo "Built $app"
