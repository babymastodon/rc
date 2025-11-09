#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "❌ This script can only run on Linux."
  exit 1
fi

# ----- helpers -----
log()   { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }

maybe_link() {
  local src="$1" dest="$2"

  # If destination exists
  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ -L "$dest" ]]; then
      local target
      target="$(readlink "$dest")"
      if [[ "$target" == "$src" ]]; then
        log "Link already correct: $dest -> $src"
      else
        warn "Link exists but wrong target ($target), fixing..."
        rm "$dest"
        ln -s "$src" "$dest"
        log "Fixed link: $dest -> $src"
      fi
    else
      log "Exists and not a link: $dest (skipping)"
    fi
  else
    ln -s "$src" "$dest"
    log "Linked: $dest -> $src"
  fi
}

ensure_line_in_file() {
  local line="$1" file="$2"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if grep -qxF "$line" "$file"; then
    log "Line already present in $(basename "$file")"
  else
    printf "%s\n" "$line" >> "$file"
    log "Appended to $(basename "$file"): $line"
  fi
}

# ----- run common instructions -----
if [[ -f "$PWD/install_basic.sh" ]]; then
  log "Running common installer: install_basic.sh"
  bash "$PWD/install_basic.sh"
else
  warn "install_basic.sh not found in current directory ($PWD) — skipping."
fi

# ----- link .bashrc_linux -----
maybe_link "$PWD/bash/bashrc_linux" "$HOME/.bashrc_linux"

# ----- ensure .bashrc sources .bashrc_linux only once -----
ensure_line_in_file "source ~/.bashrc_linux" "$HOME/.bashrc"

# ----- reload shell config (best-effort) -----
if [[ -f "$HOME/.bashrc_linux" ]]; then
  # shellcheck disable=SC1090
  source "$HOME/.bashrc_linux" || true
  log "Sourced ~/.bashrc_linux"
fi

log "Done."

