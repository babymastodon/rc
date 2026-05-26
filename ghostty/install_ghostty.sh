#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ----- helpers -----
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

install_ghostty_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    return
  fi

  require_command brew

  if brew list --cask ghostty >/dev/null 2>&1; then
    log "Ghostty is already installed via Homebrew."
  else
    log "Installing Ghostty with Homebrew..."
    brew install --cask ghostty
  fi
}

# robust symlink creator that verifies/fixes target
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
      warn "Exists and not a link: $dest (skipping)"
    fi
  else
    ln -s "$src" "$dest"
    log "Linked: $dest -> $src"
  fi
}

# ----- install app on macOS -----
install_ghostty_macos

# ----- link configs (via maybe_link) -----
log "Linking Ghostty configuration..."
mkdir -p "$HOME/.config/ghostty/" "$HOME/.config/ghostty/themes/"
maybe_link "$SCRIPT_DIR/ghostty.conf"              "$HOME/.config/ghostty/config"
maybe_link "$SCRIPT_DIR/monokai-custom.theme"         "$HOME/.config/ghostty/themes/monokai-custom.theme"
maybe_link "$SCRIPT_DIR/monokai-custom-light.theme"    "$HOME/.config/ghostty/themes/monokai-custom-light.theme"
