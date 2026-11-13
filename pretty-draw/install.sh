#!/usr/bin/env bash
# Builds Pretty Draw, replaces the copy in /Applications and launches it.
set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
"$root/build.sh"

osascript -e 'tell application id "com.zazencodes.prettydraw" to quit' 2>/dev/null || true
# Opening the new copy while the old one is still quitting fails, so wait for it to go.
while pgrep -f "/Applications/Pretty Draw.app/Contents/MacOS/PrettyDraw" >/dev/null; do sleep 0.1; done
rm -rf "/Applications/Pretty Draw.app"
ditto "$root/build/Pretty Draw.app" "/Applications/Pretty Draw.app"
open "/Applications/Pretty Draw.app"
echo "Installed /Applications/Pretty Draw.app"
