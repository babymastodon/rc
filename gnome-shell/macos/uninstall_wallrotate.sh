#!/usr/bin/env bash
set -euo pipefail

PLIST_PATH="$HOME/Library/LaunchAgents/com.user.wallrotate.plist"
SCRIPT_PATH="$HOME/bin/wallrotate.sh"

# ---- UNLOAD JOB ----
if [[ -f "$PLIST_PATH" ]]; then
  echo "Unloading LaunchAgent..."
  launchctl unload "$PLIST_PATH" 2>/dev/null || true
  rm -f "$PLIST_PATH"
else
  echo "No LaunchAgent found."
fi

# ---- LEAVE SCRIPT IN PLACE ----
if [[ -f "$SCRIPT_PATH" ]]; then
  echo "Leaving $SCRIPT_PATH in place (shared script)."
  echo "Remove manually if no longer needed."
fi

echo "✅ Uninstalled wallpaper rotation service."
