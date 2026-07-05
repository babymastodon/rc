#!/usr/bin/env bash
set -euo pipefail

log()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HERDR_DESKTOP_SRC="${HERDR_DESKTOP_SRC:-$SCRIPT_DIR/herdr.desktop}"
HERDR_DESKTOP_DST="${HERDR_DESKTOP_DST:-$HOME/.local/share/applications/herdr.desktop}"
HERDR_ICON_DIR="${HERDR_ICON_DIR:-$HOME/.local/share/icons/hicolor/scalable/apps}"
HERDR_ICON_DST="${HERDR_ICON_DST:-$HERDR_ICON_DIR/herdr.svg}"
HERDR_DESKTOP_MARKER="X-Herdr-Managed=true"

remove_desktop_entry() {
  local target

  if [[ -L "$HERDR_DESKTOP_DST" ]]; then
    target="$(readlink "$HERDR_DESKTOP_DST")"
    if [[ "$target" != "$HERDR_DESKTOP_SRC" ]]; then
      warn "Desktop entry points elsewhere; leaving it unchanged: ${HERDR_DESKTOP_DST} -> ${target}"
      return
    fi

    rm -f "$HERDR_DESKTOP_DST"
    log "Removed desktop entry: ${HERDR_DESKTOP_DST}"
  elif [[ -f "$HERDR_DESKTOP_DST" ]] && grep -Fxq "$HERDR_DESKTOP_MARKER" "$HERDR_DESKTOP_DST"; then
    rm -f "$HERDR_DESKTOP_DST"
    log "Removed managed desktop entry: ${HERDR_DESKTOP_DST}"
  elif [[ -e "$HERDR_DESKTOP_DST" ]]; then
    warn "Desktop entry is not a managed symlink; leaving it unchanged: ${HERDR_DESKTOP_DST}"
  else
    log "Desktop entry is already absent: ${HERDR_DESKTOP_DST}"
  fi
}

remove_icon() {
  if [[ -e "$HERDR_ICON_DST" || -L "$HERDR_ICON_DST" ]]; then
    rm -f "$HERDR_ICON_DST"
    log "Removed icon: ${HERDR_ICON_DST}"
  else
    log "Icon is already absent: ${HERDR_ICON_DST}"
  fi
}

remove_desktop_entry
remove_icon
update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
gtk-update-icon-cache "$HOME/.local/share/icons/hicolor" -f >/dev/null 2>&1 || true
