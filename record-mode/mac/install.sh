#!/usr/bin/env bash
# Builds Record Mode, replaces the copy in /Applications and launches it.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
"$root/mac/build.sh"

pkill -x RecordMode || true
rm -rf "/Applications/Record Mode.app"
ditto "$root/build/Record Mode.app" "/Applications/Record Mode.app"
open "/Applications/Record Mode.app"
echo "Installed /Applications/Record Mode.app"
