#!/usr/bin/env bash
set -euo pipefail

# ----- helpers -----
log()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }

# ----- run common instructions -----
if [[ -f "$PWD/install_basic.sh" ]]; then
  log "Running common installer: install_basic.sh"
  bash "$PWD/install_basic.sh"
else
  warn "install_basic.sh not found in $PWD — skipping."
fi

# ----- link ~/.bashrc_mac -----
if [[ -f "$PWD/bashrc_mac" ]]; then
  ln -sf "$PWD/bashrc_mac" "$HOME/.bashrc_mac"
  log "Linked: $PWD/bashrc_mac -> ~/.bashrc_mac"
else
  warn "bashrc_mac not found in $PWD — skipping link."
fi

# ----- ensure ~/.bashrc sources ~/.bashrc_mac only once -----
BASHRC="$HOME/.bashrc"
mkdir -p "$(dirname "$BASHRC")"
touch "$BASHRC"

if grep -qxF "source ~/.bashrc_mac" "$BASHRC"; then
  log "~/.bashrc already sources ~/.bashrc_mac"
else
  log "Adding source line to ~/.bashrc"
  tmpfile="$(mktemp)"
  # keep existing content but remove any stale/partial lines mentioning bashrc_mac
  grep -v 'bashrc_mac' "$BASHRC" > "$tmpfile" || true
  echo "source ~/.bashrc_mac" >> "$tmpfile"
  mv "$tmpfile" "$BASHRC"
fi

# ----- reload for current session (best-effort) -----
# shellcheck disable=SC1090
source "$HOME/.bashrc" || true
log "Sourced ~/.bashrc"

log "Done."

