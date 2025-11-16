#!/usr/bin/env bash
set -euo pipefail

# ----- helpers -----
log()   { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }
need_sudo() { if [[ $EUID -ne 0 ]]; then echo "sudo"; fi; }
SUDO="$(need_sudo || true)"

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

# ----- link configs (via maybe_link) -----
log "Linking Ghotty configuration…"
mkdir -p "$HOME/.config/ghostty/" "$HOME/.config/ghostty/themes/"
maybe_link "$PWD/ghostty.conf"              "$HOME/.config/ghostty/ghostty.conf"
maybe_link "$PWD/monokai-custom.theme"         "$HOME/.config/ghostty/themes/monokai-custom.theme"
maybe_link "$PWD/monokai-custom-light.theme"    "$HOME/.config/ghostty/themes/monokai-custom-light.theme"
