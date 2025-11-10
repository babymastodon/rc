#!/usr/bin/env bash
set -euo pipefail

# ---- CONFIG ----
BASE_DIR="$HOME/Pictures/wallpapers"          # search wallpapers here
BIN_DIR="$HOME/bin"
SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/wallrotate.sh"
SCRIPT_DEST="$BIN_DIR/wallrotate.sh"
PLIST_PATH="$HOME/Library/LaunchAgents/com.user.wallrotate.plist"

err(){ printf "Error: %s\n" "$*" >&2; exit 1; }

command -v launchctl >/dev/null 2>&1 || err "launchctl not found (macOS only)."
[[ -d "$BASE_DIR" ]] || err "Base directory not found: $BASE_DIR"
[[ -f "$SCRIPT_SRC" ]] || err "wallrotate.sh not found at: $SCRIPT_SRC"

# ---- UTIL: list dirs (recursively) that contain at least 1 image ----
list_valid_dirs() {
  find "$BASE_DIR" -type f \( \
      -iname '*.jpg'  -o -iname '*.jpeg' -o -iname '*.png'  -o \
      -iname '*.webp' -o -iname '*.bmp'  -o -iname '*.gif' \
    \) -print0 \
  | xargs -0 -n1 dirname \
  | awk -v base="$BASE_DIR/" '{ sub("^"base, "", $0); if(length($0)>0) print }' \
  | sort -u
}

# ---- UTIL: print options in transposed (vertical) columns ----
print_columns() {
  local termwidth cols rows r c idx
  termwidth=$(tput cols 2>/dev/null || echo 80)
  local COLW=30
  cols=$(( termwidth / COLW ))
  (( cols < 1 )) && cols=1
  rows=$(( ((${#PICK_OPTS[@]} + cols - 1)) / cols ))

  for ((r=0; r<rows; r++)); do
    for ((c=0; c<cols; c++)); do
      idx=$(( c * rows + r ))
      [[ $idx -ge ${#PICK_OPTS[@]} ]] && continue
      printf "%3d) %-*s" "$((idx+1))" $((COLW-6)) "${PICK_OPTS[idx]}" >&3
    done
    printf "\n" >&3
  done
}

# ---- Picker ----
pick_dir() {
  local options selection choice
  options="$(list_valid_dirs || true)"
  [[ -n "$options" ]] || err "No folders with images found under: $BASE_DIR"

  mapfile -t PICK_OPTS <<<"$options"
  [[ ${#PICK_OPTS[@]} -gt 0 ]] || err "No folders to select."

  exec 3>/dev/tty 4</dev/tty
  printf "Choose wallpaper folder (relative to %s):\n\n" "$BASE_DIR" >&3
  print_columns
  printf "\n" >&3

  while :; do
    printf "Number> " >&3
    IFS= read -r choice <&4 || { exec 3>&- 4<&-; err "No selection made."; }
    [[ "$choice" =~ ^[0-9]+$ ]] || { printf "Please enter a number.\n" >&3; continue; }
    (( choice>=1 && choice<=${#PICK_OPTS[@]} )) || { printf "Out of range.\n" >&3; continue; }
    selection="${PICK_OPTS[choice-1]}"
    break
  done

  exec 3>&- 4<&-
  [[ -n "$selection" ]] || err "No selection made."
  printf "%s\n" "$selection"
}

# ---- INPUT (arg or picker) ----
ARG="${1:-}"
if [[ -z "$ARG" ]]; then
  ARG="$(pick_dir)"
fi

TARGET_DIR="$BASE_DIR/$ARG"
[[ -d "$TARGET_DIR" ]] || err "Directory does not exist: $TARGET_DIR"

# Verify it has images
if ! find "$TARGET_DIR" -type f \( \
      -iname '*.jpg'  -o -iname '*.jpeg' -o -iname '*.png'  -o \
      -iname '*.webp' -o -iname '*.bmp'  -o -iname '*.gif' \
    \) | head -n1 | grep -q . ; then
  err "No image files found under: $TARGET_DIR"
fi

# ---- INSTALL wallrotate.sh ----
mkdir -p "$BIN_DIR"
echo "Installing wallrotate.sh to $SCRIPT_DEST..."
cp "$SCRIPT_SRC" "$SCRIPT_DEST"
chmod +x "$SCRIPT_DEST"

# ---- CREATE LaunchAgent plist ----
echo "Creating LaunchAgent plist..."
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
      <string>$SCRIPT_DEST "$ARG"</string>
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

# ---- RELOAD LAUNCHD ----
echo "Loading LaunchAgent..."
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo "✅ Installed wallpaper rotator — runs every 60 seconds with wallpaper dir:"
echo "   $TARGET_DIR"

