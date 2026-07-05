#!/usr/bin/env bash
set -euo pipefail

log()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HERDR_DESKTOP_SRC="${HERDR_DESKTOP_SRC:-$SCRIPT_DIR/herdr.desktop}"
HERDR_DESKTOP_DST="${HERDR_DESKTOP_DST:-$HOME/.local/share/applications/herdr.desktop}"
HERDR_ICON_URL="${HERDR_ICON_URL:-https://raw.githubusercontent.com/babymastodon/herdr/20d60f92e97dbe9ae38111abd8286338bee10361/assets/logo.svg}"
HERDR_ICON_DIR="${HERDR_ICON_DIR:-$HOME/.local/share/icons/hicolor/scalable/apps}"
HERDR_ICON_DST="${HERDR_ICON_DST:-$HERDR_ICON_DIR/herdr.svg}"

link_desktop_entry() {
  local backup

  if [[ ! -f "$HERDR_DESKTOP_SRC" ]]; then
    warn "Desktop entry source not found at ${HERDR_DESKTOP_SRC}; skipping desktop integration."
    return
  fi

  mkdir -p "$(dirname "$HERDR_DESKTOP_DST")"

  if [[ -L "$HERDR_DESKTOP_DST" ]]; then
    if [[ "$(readlink "$HERDR_DESKTOP_DST")" == "$HERDR_DESKTOP_SRC" ]]; then
      log "Desktop entry already correct: ${HERDR_DESKTOP_DST} -> ${HERDR_DESKTOP_SRC}"
      return
    fi

    warn "Replacing existing desktop entry symlink at ${HERDR_DESKTOP_DST}."
    rm -f "$HERDR_DESKTOP_DST"
  elif [[ -e "$HERDR_DESKTOP_DST" ]]; then
    backup="${HERDR_DESKTOP_DST}.bak.$(date +%Y%m%d%H%M%S)"
    mv "$HERDR_DESKTOP_DST" "$backup"
    log "Backed up existing desktop entry: ${backup}"
  fi

  ln -s "$HERDR_DESKTOP_SRC" "$HERDR_DESKTOP_DST"
  log "Linked desktop entry: ${HERDR_DESKTOP_DST} -> ${HERDR_DESKTOP_SRC}"
}

install_icon() {
  local tmp_icon

  if ! command -v curl >/dev/null 2>&1; then
    warn "curl is not installed; skipping icon install."
    return
  fi

  mkdir -p "$HERDR_ICON_DIR"
  tmp_icon="$(mktemp)"
  if ! curl -fsSL "$HERDR_ICON_URL" -o "$tmp_icon"; then
    rm -f "$tmp_icon"
    warn "Failed to download icon from ${HERDR_ICON_URL}; skipping icon install."
    return
  fi

  install -m 0644 "$tmp_icon" "$HERDR_ICON_DST"
  rm -f "$tmp_icon"
  gtk-update-icon-cache "$HOME/.local/share/icons/hicolor" -f >/dev/null 2>&1 || true
  log "Installed icon: ${HERDR_ICON_DST} from ${HERDR_ICON_URL}"
}

link_desktop_entry
install_icon
update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
