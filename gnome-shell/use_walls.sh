#!/usr/bin/env bash
# set-azwallpaper-dir.sh
# Usage: set-azwallpaper-dir.sh [subdir-under-Pictures]
# Default: walls/nord

set -euo pipefail

EXT_PATH="/org/gnome/shell/extensions/azwallpaper@azwallpaper.gitlab.com/"
KEY="slideshow-directory"
DEFAULT_SUBDIR="walls/nord"

err() { printf "Error: %s\n" "$*" >&2; exit 1; }

# --- prerequisites
command -v dconf >/dev/null 2>&1 || err "dconf not found. Install dconf-cli first."

# --- args
SUBDIR=${1:-$DEFAULT_SUBDIR}

# --- resolve and validate directory
BASE_DIR="${HOME}/Pictures"
TARGET_DIR="${BASE_DIR}/${SUBDIR}"

if [[ ! -d "$TARGET_DIR" ]]; then
  err "Directory does not exist: $TARGET_DIR"
fi
if [[ ! -r "$TARGET_DIR" ]]; then
  err "Directory is not readable: $TARGET_DIR"
fi

# Optional: ensure it contains at least one common image file
shopt -s nullglob
images=( "$TARGET_DIR"/*.{jpg,jpeg,png,webp,bmp,gif} )
shopt -u nullglob
if (( ${#images[@]} == 0 )); then
  printf "Warning: no image files found in '%s'. The extension may have nothing to rotate.\n" "$TARGET_DIR" >&2
fi

# --- write setting with dconf
dconf load "$EXT_PATH" <<EOF
[/]
${KEY}='${TARGET_DIR}'
EOF

# --- verify and report
READBACK=$(dconf read "${EXT_PATH}${KEY}" 2>/dev/null || true)

printf "Success: set %s to %s\n" "${KEY}" "${TARGET_DIR}"
if [[ -n "$READBACK" ]]; then
  printf "dconf now reports: %s\n" "$READBACK"
fi
printf "AZWallpaper will rotate your wallpaper from:\n  %s\n" "$TARGET_DIR"
