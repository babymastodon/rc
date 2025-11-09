#!/usr/bin/env bash
set -euo pipefail

log()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[-]\033[0m %s\n" "$*"; }

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
        rm -f "$dest"
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

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "Missing required command: $1"; exit 1; }
}

run_dnf() {
  # Use sudo if not root
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    need_cmd sudo
    sudo dnf "$@"
  else
    dnf "$@"
  fi
}

install_ghostty_via_copr() {
  # Only attempt on Fedora-like systems with dnf
  if ! command -v dnf >/dev/null 2>&1; then
    warn "dnf not found; skipping COPR install."
    return 0
  fi

  if command -v ghostty >/dev/null 2>&1; then
    log "Ghostty already installed: $(command -v ghostty)"
    return 0
  fi

  log "Installing dnf-plugins-core (for COPR support)…"
  run_dnf -y install dnf-plugins-core

  log "Enabling COPR: scottames/ghostty…"
  # -y to auto-confirm; ignore if already enabled
  if ! run_dnf -y copr enable scottames/ghostty; then
    warn "COPR may already be enabled or failed to enable; continuing."
  fi

  log "Installing Ghostty…"
  run_dnf -y install ghostty

  if command -v ghostty >/dev/null 2>&1; then
    log "Ghostty installed successfully: $(command -v ghostty)"
  else
    err "Ghostty installation appears to have failed."
    exit 1
  fi
}

main() {
  install_ghostty_via_copr

  mkdir -p "$HOME/.config/ghostty"

  # Adjust the source path below if your repo/file is elsewhere
  maybe_link "$PWD/ghostty.config" "$HOME/.config/ghostty/config"
}

main "$@"
