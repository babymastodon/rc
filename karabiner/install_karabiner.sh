#!/usr/bin/env bash
set -euo pipefail

log()   { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

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

if [[ ! -d "/Applications/Karabiner-Elements.app" && ! -d "$HOME/Applications/Karabiner-Elements.app" ]]; then
  warn "Karabiner-Elements app not found. Install it first from https://karabiner-elements.pqrs.org"
fi

CONF_SRC="$PWD/karabiner.json"
CONF_DST="$HOME/.config/karabiner/karabiner.json"

if [[ ! -f "$CONF_SRC" ]]; then
  err "Config source not found at: $CONF_SRC"
  exit 1
fi

log "Linking Karabiner configuration..."
mkdir -p "$(dirname "$CONF_DST")"
maybe_link "$CONF_SRC" "$CONF_DST"

log "Done."
