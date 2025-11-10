#!/usr/bin/env bash
# use_walls.sh
# - Recursively finds wallpaper sets under ~/Pictures/wallpapers that contain images
# - Lists directories in transposed (vertical) columns
# - Uses numbered selection (no fzf)
# - Sets AZWallpaper dir via gsettings and nudges slideshow

set -euo pipefail

SCHEMA="org.gnome.shell.extensions.azwallpaper"
KEY="slideshow-directory"
WALL_BASE="$HOME/Pictures/wallpapers"
EXTDIR="${EXTDIR:-$HOME/.local/share/gnome-shell/extensions/azwallpaper@azwallpaper.gitlab.com}"

err(){ printf "Error: %s\n" "$*" >&2; exit 1; }

command -v gsettings >/dev/null 2>&1 || err "gsettings not found."
[[ -d "$EXTDIR/schemas" ]] || err "Schemas dir not found: $EXTDIR/schemas"
[[ -d "$WALL_BASE" ]] || err "Wallpaper base not found: $WALL_BASE"

# Find valid dirs (only those containing image files)
list_valid_dirs() {
  find "$WALL_BASE" -type f \( \
      -iname '*.jpg'  -o -iname '*.jpeg' -o -iname '*.png' -o \
      -iname '*.webp' -o -iname '*.bmp'  -o -iname '*.gif' \
    \) -printf '%h\n' | sort -u | awk -v base="$WALL_BASE/" '{ sub("^"base, "", $0); print }'
}

# Print vertically packed columns (transposed)
print_columns() {
  local termwidth rows cols i r c idx
  termwidth=${COLUMNS:-$(tput cols || echo 80)}
  cols=$(( termwidth / 30 ))
  cols=$(( cols < 1 ? 1 : cols ))
  rows=$(( ((${#arr[@]} + cols - 1)) / cols ))

  for ((r=0; r<rows; r++)); do
    for ((c=0; c<cols; c++)); do
      idx=$(( c * rows + r ))
      [[ $idx -ge ${#arr[@]} ]] && continue
      printf "%2d) %-27s" "$((idx+1))" "${arr[idx]}" >&3
    done
    printf "\n" >&3
  done
}

# Show current selection (if any) from gsettings
print_current_selection() {
  local val rel
  val="$(gsettings --schemadir "$EXTDIR/schemas" get "$SCHEMA" "$KEY" 2>/dev/null || true)"
  # Strip single quotes that gsettings includes around strings
  [[ -n "$val" ]] && val="${val#\'}" && val="${val%\'}"

  # Only print if it's a real, existing directory
  if [[ -n "${val:-}" && -d "$val" ]]; then
    if [[ "$val" == "$WALL_BASE"* ]]; then
      rel="${val#"$WALL_BASE"/}"
      echo "$rel"
    else
      echo "$val"
    fi
  fi
}

pick_dir() {
  local options selection
  options="$(list_valid_dirs || true)"
  [[ -n "$options" ]] || err "No folders with images found under: $WALL_BASE"

  mapfile -t arr <<<"$options"
  [[ ${#arr[@]} -gt 0 ]] || err "No folders to select."

  cur=$(print_current_selection)

  # Open TTY for I/O
  exec 3>/dev/tty 4</dev/tty
  printf "Choose wallpaper folder [$cur]:\n\n" >&3

  print_columns
  printf "\n" >&3

  local choice
  while :; do
    printf "Number> " >&3
    IFS= read -r choice <&4 || { exec 3>&- 4<&-; err "No selection made."; }

    # Exit cleanly if input is empty
    [[ -z "$choice" ]] && {
      exec 3>&- 4<&-
      printf "No selection made. Exiting.\n" >&2
      exit 1
    }

    [[ "$choice" =~ ^[0-9]+$ ]] || { printf "Please enter a number.\n" >&3; continue; }
    (( choice>=1 && choice<=${#arr[@]} )) || { printf "Out of range.\n" >&3; continue; }
    selection="${arr[choice-1]}"
    break
  done

  exec 3>&- 4<&-
  [[ -n "$selection" ]] || err "No selection made."
  printf "%s\n" "$selection"

}

set_dir() {
  local subdir="$1"
  local target="$WALL_BASE/$subdir"

  [[ -d "$target" ]] || err "Directory does not exist: $target"
  [[ -r "$target" ]] || err "Directory not readable: $target"

  if ! find "$target" -type f \( \
        -iname '*.jpg'  -o -iname '*.jpeg' -o -iname '*.png' -o \
        -iname '*.webp' -o -iname '*.bmp'  -o -iname '*.gif' \
      \) | read -r _; then
    err "No image files found under: $target"
  fi

  gsettings --schemadir "$EXTDIR/schemas" set "$SCHEMA" "$KEY" "$target"
  gsettings --schemadir "$EXTDIR/schemas" set "$SCHEMA" slideshow-change-slide-event 2

  local readback
  readback=$(gsettings --schemadir "$EXTDIR/schemas" get "$SCHEMA" "$KEY" || true)
  printf "Success: %s set to %s\n" "$KEY" "$target"
  [[ -n "$readback" ]] && printf "gsettings reports: %s\n" "$readback"
  printf "AZWallpaper will rotate from:\n  %s\n" "$target"
}

# --- Main ---
if [[ $# -eq 0 ]]; then
  if ! sel="$(pick_dir)"; then
    exit 0
  fi
  set_dir "$sel"
else
  set_dir "$1"
fi

