#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()   { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

require_command() {
  local cmd="$1"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    err "Missing required command: $cmd"
    exit 1
  fi
}

install_karabiner_macos() {
  require_command brew

  if brew list --cask karabiner-elements >/dev/null 2>&1; then
    log "Karabiner-Elements is already installed via Homebrew."
  else
    log "Installing Karabiner-Elements with Homebrew..."
    brew install --cask karabiner-elements
  fi
}

maybe_link() {
  local src="$1" dest="$2"

  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ -L "$dest" ]]; then
      local target
      target="$(readlink "$dest")"
      if [[ "$target" == "$src" ]]; then
        log "Link already correct: $dest -> $src"
      else
        warn "Link exists but wrong target ($target), fixing..."
        rm -f "$dest"
        ln -s "$src" "$dest"
        log "Fixed link: $dest -> $src"
      fi
    else
      local backup="${dest}.bak"
      warn "Existing file is not a symlink, moving it to $backup"
      mv "$dest" "$backup"
      ln -s "$src" "$dest"
      log "Linked: $dest -> $src"
    fi
  else
    ln -s "$src" "$dest"
    log "Linked: $dest -> $src"
  fi
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  err "This script expects macOS."
  exit 1
fi

install_karabiner_macos

CONF_SRC="$SCRIPT_DIR/karabiner.json"
CONF_DST="$HOME/.config/karabiner/karabiner.json"

if [[ ! -f "$CONF_SRC" ]]; then
  err "Config source not found at: $CONF_SRC"
  exit 1
fi

log "Linking Karabiner configuration..."
mkdir -p "$(dirname "$CONF_DST")"
maybe_link "$CONF_SRC" "$CONF_DST"

log "Done."
