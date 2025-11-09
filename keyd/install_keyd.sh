#!/usr/bin/env bash
set -euo pipefail

# ----- helpers -----
log()   { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }
need_sudo() { if [[ $EUID -ne 0 ]]; then echo "sudo"; fi; }
SUDO="$(need_sudo || true)"

# Ensure Fedora/RHEL family
if ! command -v dnf >/dev/null 2>&1; then
  err "This script expects Fedora (dnf not found)."
  exit 1
fi

REPO_DIR="$HOME/code/keyd"
CONF_SRC="$PWD/default.conf"
CONF_DST="/etc/keyd/default.conf"

log "Installing/Configuring keyd…"

# ----- ensure build deps -----
need_group=false
for c in make gcc; do
  command -v "$c" >/dev/null 2>&1 || need_group=true
done

if $need_group; then
  log "Installing build tools (@development-tools)…"
  $SUDO dnf -y groupinstall @development-tools
else
  log "Build tools already present."
fi

if ! command -v git >/dev/null 2>&1; then
  log "Installing git…"
  $SUDO dnf -y install git
else
  log "git already present."
fi

# ----- place config (only if missing) -----
$SUDO mkdir -p /etc/keyd/
if [[ -f "$CONF_DST" || -L "$CONF_DST" ]]; then
  log "Config already exists at $CONF_DST — skipping link."
else
  if [[ -f "$CONF_SRC" ]]; then
    $SUDO ln -s "$CONF_SRC" "$CONF_DST"
    log "Linked config: $CONF_SRC -> $CONF_DST"
  else
    warn "Config source not found at: $CONF_SRC (skipping link)"
  fi
fi

# ----- install keyd if missing -----
if ! command -v keyd >/dev/null 2>&1; then
  log "keyd not found — building from source…"

  mkdir -p "$(dirname "$REPO_DIR")"
  if [[ -d "$REPO_DIR/.git" ]]; then
    log "Updating existing repo…"
    git -C "$REPO_DIR" fetch --tags --quiet || true
    git -C "$REPO_DIR" pull --rebase --quiet || true
  else
    log "Cloning keyd…"
    git clone https://github.com/rvaiya/keyd "$REPO_DIR"
  fi

  pushd "$REPO_DIR" >/dev/null
  make
  $SUDO make install
  $SUDO systemctl daemon-reload
  $SUDO systemctl enable --now keyd
  popd >/dev/null

  log "keyd installed and service started."
else
  log "keyd already installed: $(keyd -v 2>/dev/null || echo 'version lookup skipped')"
  # Ensure service is enabled & running
  $SUDO systemctl daemon-reload || true
  $SUDO systemctl enable keyd >/dev/null 2>&1 || true
  $SUDO systemctl restart keyd || warn "Could not restart keyd; check logs with: sudo journalctl -u keyd -e"
fi

log "Done."

