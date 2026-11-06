#!/usr/bin/env bash
# Builds Facecam, replaces the copy in /Applications and launches it.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
"$root/mac/build.sh"

pkill -x Facecam || true
rm -rf "/Applications/Facecam.app"
ditto "$root/build/Facecam.app" "/Applications/Facecam.app"
open "/Applications/Facecam.app"
echo "Installed /Applications/Facecam.app"
