#!/usr/bin/env bash
set -euo pipefail

# ----- helpers -----
log()   { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }

# ----- run common instructions -----
if [[ -f "$PWD/install_basic.sh" ]]; then
  log "Running common installer: install_basic.sh"
  bash "$PWD/install_basic.sh"
else
  warn "install_basic.sh not found in current directory ($PWD) — skipping."
fi

# ----- link .bashrc_linux -----
if [[ -f "$PWD/bashrc_linux" ]]; then
  ln -sf "$PWD/bashrc_linux" "$HOME/.bashrc_linux"
  log "Linked: $PWD/bashrc_linux -> ~/.bashrc_linux"
else
  warn "bashrc_linux file not found at $PWD — skipping link."
fi

# ----- ensure .bashrc sources .bashrc_linux only once -----
BASHRC="$HOME/.bashrc"
touch "$BASHRC"
if grep -qxF "source ~/.bashrc_linux" "$BASHRC"; then
  log "~/.bashrc already sources ~/.bashrc_linux"
else
  log "Adding source line to ~/.bashrc"
  {
    grep -v 'bashrc_linux' "$BASHRC" || true
    echo "source ~/.bashrc_linux"
  } > /tmp/bashrc.$$
  mv /tmp/bashrc.$$ "$BASHRC"
fi

# ----- reload shell config (best-effort) -----
if [[ -f "$HOME/.bashrc_linux" ]]; then
  # shellcheck disable=SC1090
  source "$HOME/.bashrc_linux" || true
  log "Sourced ~/.bashrc_linux"
fi

log "Done."

