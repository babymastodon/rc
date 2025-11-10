#!/usr/bin/env bash
set -euo pipefail

# ---- INPUT ----
ARG="${1:-}"
if [[ -z "$ARG" ]]; then
  echo "Usage: $0 <wallpaper_subdir>"
  echo "Example: $0 nord"
  exit 1
fi

BIN_DIR="$HOME/bin"
SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/wallrotate.sh"
SCRIPT_DEST="$BIN_DIR/wallrotate.sh"
PLIST_PATH="$HOME/Library/LaunchAgents/com.user.wallrotate.plist"

# ---- ENSURE BIN EXISTS ----
mkdir -p "$BIN_DIR"

# ---- COPY SCRIPT ----
echo "Installing wallrotate.sh to $SCRIPT_DEST..."
cp "$SCRIPT_SRC" "$SCRIPT_DEST"
chmod +x "$SCRIPT_DEST"

# ---- CREATE SINGLE GLOBAL PLIST ----
echo "Creating global LaunchAgent plist..."
cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.user.wallrotate</string>

    <key>ProgramArguments</key>
    <array>
      <string>/bin/bash</string>
      <string>-lc</string>
      <string>$SCRIPT_DEST $ARG</string>
    </array>

    <key>StartInterval</key>
    <integer>60</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>LimitLoadToSessionType</key>
    <array><string>Aqua</string></array>
  </dict>
</plist>
EOF

# ---- RELOAD LAUNCHD JOB ----
echo "Loading LaunchAgent..."
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo "✅ Installed wallpaper rotator — runs every 60 seconds with arg '$ARG'."
