#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

log()   { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }
need_sudo() { if [[ $EUID -ne 0 ]]; then echo "sudo"; fi; }
SUDO="$(need_sudo || true)"

maybe_link() {
  local src="$1" dest="$2"

  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ -L "$dest" ]]; then
      local target
      target="$(readlink "$dest")"
      if [[ "$target" == "$src" ]]; then
        log "Link already correct: $dest -> $src"
      else
        warn "Link exists but has the wrong target ($target), fixing..."
        rm -f "$dest"
        ln -s "$src" "$dest"
        log "Fixed link: $dest -> $src"
      fi
    else
      warn "Exists and is not a link: $dest (skipping)"
    fi
  else
    ln -s "$src" "$dest"
    log "Linked: $dest -> $src"
  fi
}

if ! command -v dnf >/dev/null 2>&1; then
  err "This script expects Fedora (dnf not found)."
  exit 1
fi

if ! command -v alacritty >/dev/null 2>&1 && ! rpm -q alacritty >/dev/null 2>&1; then
  log "Installing Alacritty..."
  $SUDO dnf -y install alacritty || {
    err "Failed to install Alacritty via DNF."
    exit 1
  }
else
  log "Alacritty already installed: $(alacritty --version 2>/dev/null | head -n1 || echo 'version lookup skipped')"
fi

if ! command -v gsettings >/dev/null 2>&1; then
  log "Installing gsettings for GNOME theme detection..."
  $SUDO dnf -y install glib2 || {
    err "Failed to install gsettings via DNF."
    exit 1
  }
fi

log "Installing Nerd Fonts for Alacritty..."
"$SCRIPT_DIR/../fonts/install_nerdfonts.sh"

log "Linking Alacritty configuration..."
mkdir -p "$CONFIG_HOME/alacritty/themes"
maybe_link "$SCRIPT_DIR/alacritty.toml" "$CONFIG_HOME/alacritty/alacritty.toml"
maybe_link "$SCRIPT_DIR/MonokaiCustom.toml" "$CONFIG_HOME/alacritty/themes/MonokaiCustom.toml"
maybe_link "$SCRIPT_DIR/MonokaiCustomLight.toml" "$CONFIG_HOME/alacritty/themes/MonokaiCustomLight.toml"

log "Installing the Alacritty theme watcher..."
mkdir -p "$HOME/.local/bin"
maybe_link "$SCRIPT_DIR/alacritty-theme-watcher.sh" "$HOME/.local/bin/alacritty-theme-watcher.sh"
chmod +x "$SCRIPT_DIR/alacritty-theme-watcher.sh"

log "Selecting the current GNOME theme..."
"$HOME/.local/bin/alacritty-theme-watcher.sh" --once

log "Installing the Alacritty theme watcher service..."
mkdir -p "$CONFIG_HOME/systemd/user"
maybe_link "$SCRIPT_DIR/alacritty-theme-watcher.service" "$CONFIG_HOME/systemd/user/alacritty-theme-watcher.service"

if systemctl --user show-environment >/dev/null 2>&1; then
  log "Reloading the user systemd daemon and enabling the theme watcher..."
  systemctl --user daemon-reload
  systemctl --user enable alacritty-theme-watcher.service
  systemctl --user restart alacritty-theme-watcher.service
  systemctl --user status alacritty-theme-watcher.service --no-pager --full || true
else
  warn "No systemd user instance was detected. Start the watcher manually with:
    $HOME/.local/bin/alacritty-theme-watcher.sh"
fi

log "Done."
