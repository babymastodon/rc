#!/usr/bin/env bash
set -euo pipefail

# Name of subdir
SUB=${1:-walls/nord}

# Directory of your wallpapers
DIR="$HOME/Pictures/$SUB"

# Pick a random image (jpg/jpeg/png/heic)
PIC="$(find "$DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.heic' \) | sort -R | head -n 1)"

# If nothing found, bail politely
[ -z "$PIC" ] && exit 0

# Set on all Spaces/Desktops (multi-monitor safe)
osascript <<AS
tell application "System Events"
  repeat with d in desktops
    set picture of d to POSIX file "$PIC"
  end repeat
end tell
AS
