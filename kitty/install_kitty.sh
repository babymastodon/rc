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

# Ensure DNF exists (Fedora/RHEL family)
if ! command -v dnf >/dev/null 2>&1; then
  err "This script expects Fedora (dnf not found)."
  exit 1
fi

# ----- install kitty if missing -----
if ! command -v kitty >/dev/null 2>&1 && ! rpm -q kitty >/dev/null 2>&1; then
  log "Installing Kitty terminal…"
  $SUDO dnf -y install kitty || {
    err "Failed to install kitty via DNF."
    exit 1
  }
else
  log "Kitty already installed: $(kitty --version 2>/dev/null | head -n1 || echo 'version lookup skipped')"
fi

# ----- link configs (via maybe_link) -----
log "Linking Kitty configuration…"
mkdir -p "$HOME/.config/kitty/" "$HOME/.config/kitty/themes/"
maybe_link "$PWD/kitty.conf"              "$HOME/.config/kitty/kitty.conf"
maybe_link "$PWD/MonokaiCustom.conf"         "$HOME/.config/kitty/themes/MonokaiCustom.conf"
maybe_link "$PWD/MonokaiCustomLight.conf"    "$HOME/.config/kitty/themes/MonokaiCustomLight.conf"

# ----- install watcher script into ~/.local/bin and ensure it's executable -----
log "Installing theme watcher script…"
mkdir -p "$HOME/.local/bin"
maybe_link "$PWD/kitty-theme-watcher.sh"  "$HOME/.local/bin/kitty-theme-watcher.sh"
chmod +x "$HOME/.local/bin/kitty-theme-watcher.sh" || true

# Ensure ~/.local/bin is in PATH for future sessions (best-effort)
if [[ ":${PATH}:" != *":${HOME}/.local/bin:"* ]]; then
  warn "~/.local/bin is not in PATH for this session. Consider adding: 'export PATH=\$HOME/.local/bin:\$PATH' to your shell rc."
fi

# ----- install and enable user systemd service (via maybe_link) -----
log "Installing user systemd service for theme watcher…"
mkdir -p "$HOME/.config/systemd/user"
maybe_link "$PWD/kitty-theme-watcher.service" "$HOME/.config/systemd/user/kitty-theme-watcher.service"

# If a user systemd instance is available, enable the service
if systemctl --user 2>/dev/null >/dev/null; then
  log "Reloading user systemd daemon and enabling service…"
  systemctl --user daemon-reload
  systemctl --user enable --now kitty-theme-watcher.service
  systemctl --user status kitty-theme-watcher.service --no-pager --full || true
else
  warn "systemd user instance not detected. To run user services across logouts:
    loginctl enable-linger \"$USER\"
  Then re-run: systemctl --user daemon-reload && systemctl --user enable --now kitty-theme-watcher.service"
fi

log "Done."
