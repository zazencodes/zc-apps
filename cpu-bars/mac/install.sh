#!/usr/bin/env bash
# Builds CPU Bars, replaces the copy in /Applications and launches it.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
"$root/mac/build.sh"

pkill -x CPUBars || true
rm -rf "/Applications/CPU Bars.app"
ditto "$root/build/CPU Bars.app" "/Applications/CPU Bars.app"
open "/Applications/CPU Bars.app"
echo "Installed /Applications/CPU Bars.app"
