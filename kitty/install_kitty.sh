#!/usr/bin/env bash
set -euo pipefail

# ----- helpers -----
log()   { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }
need_sudo() { if [[ $EUID -ne 0 ]]; then echo "sudo"; fi; }
SUDO="$(need_sudo || true)"

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

# ----- link configs -----
log "Linking Kitty configuration…"
mkdir -p "$HOME/.config/kitty/"
ln -sf "$PWD/kitty.conf" "$HOME/.config/kitty/kitty.conf"

mkdir -p "$HOME/.config/kitty/themes/"
ln -sf "$PWD/MonokaiPro.conf"       "$HOME/.config/kitty/themes/MonokaiPro.conf"
ln -sf "$PWD/MonokaiProLight.conf"  "$HOME/.config/kitty/themes/MonokaiProLight.conf"

# ----- install watcher script into ~/bin and ensure it's executable -----
log "Installing theme watcher script…"
mkdir -p "$HOME/bin"
ln -sf "$PWD/kitty-theme-watcher.sh" "$HOME/bin/kitty-theme-watcher.sh"
chmod +x "$HOME/bin/kitty-theme-watcher.sh" || true

# Ensure ~/bin is in PATH for future sessions (best-effort)
if [[ ":${PATH}:" != *":${HOME}/bin:"* ]]; then
  warn "~/bin is not in PATH for this session. Consider adding: 'export PATH=\$HOME/bin:\$PATH' to your shell rc."
fi

# ----- install and enable user systemd service (link first, then reload/enable) -----
log "Installing user systemd service for theme watcher…"
mkdir -p "$HOME/.config/systemd/user"
ln -sf "$PWD/kitty-theme-watcher.service" "$HOME/.config/systemd/user/kitty-theme-watcher.service"

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

