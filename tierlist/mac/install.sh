#!/usr/bin/env bash
# Builds Tier List ZC, replaces the copy in /Applications and launches it.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
"$root/mac/build.sh"

pkill -x TierList || true
rm -rf "/Applications/Tier List ZC.app"
ditto "$root/build/Tier List ZC.app" "/Applications/Tier List ZC.app"
open "/Applications/Tier List ZC.app"
echo "Installed /Applications/Tier List ZC.app"
