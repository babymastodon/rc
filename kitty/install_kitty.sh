#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/install.sh"

# ----- helpers -----
log()   { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

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

# ----- install kitty if missing -----
if ! command -v kitty >/dev/null 2>&1; then
  log "Installing Kitty terminal…"
  rc_install_packages kitty || {
    err "Failed to install kitty with the system package manager."
    exit 1
  }
else
  log "Kitty already installed: $(kitty --version 2>/dev/null | head -n1 || echo 'version lookup skipped')"
fi

# ----- install Nerd Fonts for Kitty icons -----
log "Installing Nerd Fonts for Kitty…"
"$SCRIPT_DIR/../fonts/install_nerdfonts.sh"

# ----- link configs (via maybe_link) -----
log "Linking Kitty configuration…"
mkdir -p "$HOME/.config/kitty/" "$HOME/.config/kitty/themes/"
maybe_link "$SCRIPT_DIR/kitty.conf"              "$HOME/.config/kitty/kitty.conf"
maybe_link "$SCRIPT_DIR/MonokaiCustom.conf"         "$HOME/.config/kitty/themes/MonokaiCustom.conf"
maybe_link "$SCRIPT_DIR/MonokaiCustomLight.conf"    "$HOME/.config/kitty/themes/MonokaiCustomLight.conf"
maybe_link "$SCRIPT_DIR/MonokaiCustom.conf"         "$HOME/.config/kitty/dark-theme.auto.conf"
maybe_link "$SCRIPT_DIR/MonokaiCustomLight.conf"    "$HOME/.config/kitty/light-theme.auto.conf"
maybe_link "$SCRIPT_DIR/MonokaiCustomLight.conf"    "$HOME/.config/kitty/no-preference-theme.auto.conf"

log "Done."
