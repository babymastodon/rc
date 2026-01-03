#!/usr/bin/env bash
set -euo pipefail

# ----- helpers -----
log()   { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

need_sudo() { if [[ $EUID -ne 0 ]]; then echo "sudo"; fi; }
SUDO="$(need_sudo || true)"

# robust symlink creator (sudo-aware)
maybe_link() {
  local src="$1" dest="$2"
  local prefix="${3:-}"  # optional third arg for sudo

  if $prefix test -e "$dest" || $prefix test -L "$dest"; then
    if $prefix test -L "$dest"; then
      local target
      target="$($prefix readlink "$dest")"
      if [[ "$target" == "$src" ]]; then
        log "Link already correct: $dest -> $src"
      else
        warn "Link exists but wrong target ($target), fixing..."
        $prefix rm -f "$dest"
        $prefix ln -s "$src" "$dest"
        log "Fixed link: $dest -> $src"
      fi
    else
      warn "Exists and not a link: $dest (fixing)"
      bk="/tmp/${dest##*/}"
      $prefix mv -f "$dest" "$bk"
      log "Moved old file: $dest -> $bk"
      $prefix ln -s "$src" "$dest"
        log "Fixed link: $dest -> $src"
    fi
  else
    $prefix ln -s "$src" "$dest"
    log "Linked: $dest -> $src"
  fi
}

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
  $SUDO dnf -y install @development-tools
else
  log "Build tools already present."
fi

if ! command -v git >/dev/null 2>&1; then
  log "Installing git…"
  $SUDO dnf -y install git
else
  log "git already present."
fi

# ----- place config -----
log "Linking keyd config…"
$SUDO mkdir -p /etc/keyd/
if [[ -f "$CONF_SRC" ]]; then
  maybe_link "$CONF_SRC" "$CONF_DST" "$SUDO"
else
  warn "Config source not found at: $CONF_SRC (skipping link)"
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
