#!/usr/bin/env bash
set -euo pipefail

SCHEMA="org.gnome.desktop.interface"
KEY="color-scheme"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CONFIG_DIR="$CONFIG_HOME/alacritty"
DARK_THEME="$CONFIG_DIR/themes/MonokaiCustom.toml"
LIGHT_THEME="$CONFIG_DIR/themes/MonokaiCustomLight.toml"
ACTIVE_THEME="$CONFIG_DIR/current-theme.toml"

log()  { printf '[alacritty-theme-watcher] %s\n' "$*"; }
err()  { printf '[alacritty-theme-watcher] error: %s\n' "$*" >&2; }

usage() {
  printf 'Usage: %s [--once]\n' "$0"
}

current_scheme() {
  gsettings get "$SCHEMA" "$KEY"
}

apply_theme() {
  local scheme="$1"
  local source="$LIGHT_THEME"
  local label="light"

  if [[ "$scheme" == *dark* ]]; then
    source="$DARK_THEME"
    label="dark"
  fi

  if [[ ! -r "$source" ]]; then
    err "Theme is not readable: $source"
    return 1
  fi

  mkdir -p "$CONFIG_DIR"
  # Never follow an old current-theme symlink and overwrite its source theme.
  if [[ -L "$ACTIVE_THEME" ]]; then
    rm -f "$ACTIVE_THEME"
  fi
  if [[ -f "$ACTIVE_THEME" ]] && cmp -s "$source" "$ACTIVE_THEME"; then
    return 0
  fi

  # Keep a stable imported path so Alacritty's live config watcher reloads it.
  cp -- "$source" "$ACTIVE_THEME"
  chmod 0644 "$ACTIVE_THEME"
  log "Applied $label theme"
}

main() {
  local once=false

  if [[ $# -gt 1 ]]; then
    usage >&2
    return 2
  fi
  if [[ $# -eq 1 ]]; then
    case "$1" in
      --once) once=true ;;
      -h|--help) usage; return 0 ;;
      *) usage >&2; return 2 ;;
    esac
  fi

  for command in gsettings cmp cp chmod rm; do
    if ! command -v "$command" >/dev/null 2>&1; then
      err "Required command not found: $command"
      return 1
    fi
  done

  apply_theme "$(current_scheme)"
  if [[ "$once" == true ]]; then
    return 0
  fi

  log "Watching $SCHEMA $KEY"
  gsettings monitor "$SCHEMA" "$KEY" | while IFS= read -r _; do
    apply_theme "$(current_scheme)"
  done
}

main "$@"
