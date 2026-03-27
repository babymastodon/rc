#!/usr/bin/env bash
set -euo pipefail

# ----- helpers -----
log()   { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }
need_sudo() { if [[ $EUID -ne 0 ]]; then echo "sudo"; fi; }

OS=""
PKG_MGR=""
SUDO=""
APT_UPDATED=0

detect_os() {
  case "${OSTYPE:-unknown}" in
    darwin*)
      OS="mac"
      PKG_MGR="brew"
      SUDO=""
      if ! command -v brew >/dev/null 2>&1; then
        err "Homebrew not found. Install from https://brew.sh first."
        exit 1
      fi
      ;;
    linux-gnu*|linux*)
      OS="linux"
      if command -v dnf >/dev/null 2>&1; then
        PKG_MGR="dnf"
        SUDO="$(need_sudo || true)"
      elif command -v apt-get >/dev/null 2>&1; then
        PKG_MGR="apt"
        SUDO="$(need_sudo || true)"
      else
        err "Supported Linux distros: Fedora/RHEL (dnf) or Debian/Ubuntu (apt-get not found)."
        exit 1
      fi
      ;;
    *)
      err "Unsupported OS: $OSTYPE"
      exit 1
      ;;
  esac

  log "Detected OS: $OS (pkg manager: $PKG_MGR)"
}

install_pkgs() {
  case "$PKG_MGR" in
    dnf)
      $SUDO dnf -y install "$@"
      ;;
    apt)
      if [[ "$APT_UPDATED" -eq 0 ]]; then
        log "Running apt-get update..."
        $SUDO apt-get update -y
        APT_UPDATED=1
      fi
      $SUDO apt-get install -y "$@"
      ;;
    brew)
      brew install "$@" || true
      ;;
    *)
      err "No package manager configured."
      exit 1
      ;;
  esac
}

maybe_copy() {
  local src="$1" dest="$2"
  if [[ -e "$dest" ]]; then
    log "Exists, not copying: $dest"
  else
    cp "$src" "$dest"
    log "Copied: $src -> $dest"
  fi
}

detect_os

if ! command -v btop >/dev/null 2>&1; then
  log "Installing btop..."
  install_pkgs btop
else
  log "btop already installed: $(btop --version 2>/dev/null | head -n1 || echo 'version unknown')"
fi

mkdir -p "$HOME/.config/btop"
maybe_copy "$PWD/btop.conf" "$HOME/.config/btop/btop.conf"

log "Done."
