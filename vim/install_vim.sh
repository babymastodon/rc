#!/usr/bin/env bash
set -euo pipefail

log()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }
need_sudo() { if [[ ${EUID:-$(id -u)} -ne 0 ]]; then echo "sudo"; fi; }

SUDO="$(need_sudo || true)"
MIN_VIM_VERSION="9.0.0438"

have() {
  command -v "$1" >/dev/null 2>&1
}

version_ge() {
  local left="$1" right="$2"
  if [[ "$left" == "$right" ]]; then
    return 0
  fi

  local first
  first="$(printf '%s\n%s\n' "$right" "$left" | sort -t. -k1,1n -k2,2n -k3,3n | head -n1)"
  [[ "$first" == "$right" ]]
}

normalize_vim_version() {
  local version="$1"
  local major minor patch

  if [[ "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
    patch="${BASH_REMATCH[3]}"
    printf '%s.%s.%04d\n' "$major" "$minor" "$patch"
    return 0
  fi

  printf '%s\n' "$version"
}

detect_linux_distro() {
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    printf '%s\n' "${ID:-unknown}"
  else
    printf 'unknown\n'
  fi
}

install_vim_macos() {
  if ! have brew; then
    err "Homebrew not found. Install Homebrew first: https://brew.sh/"
    exit 1
  fi

  log "Installing Vim with Homebrew..."
  brew install vim
}

install_vim_linux() {
  local distro
  distro="$(detect_linux_distro)"

  case "$distro" in
    fedora)
      log "Installing Vim with dnf..."
      $SUDO dnf install -y vim
      ;;
    ubuntu)
      log "Installing Vim with apt..."
      $SUDO apt-get update -y
      $SUDO apt-get install -y vim
      ;;
    *)
      err "Unsupported Linux distro: ${distro}. Supported: Fedora, Ubuntu."
      exit 1
      ;;
  esac
}

get_vim_version() {
  local raw

  raw="$(vim --version 2>/dev/null | awk 'NR==1 {print $5; exit}')"
  normalize_vim_version "$raw"
}

main() {
  case "$(uname -s)" in
    Darwin)
      if have vim; then
        log "Vim already installed."
      else
        install_vim_macos
      fi
      ;;
    Linux)
      if have vim; then
        log "Vim already installed."
      else
        install_vim_linux
      fi
      ;;
    *)
      err "Unsupported OS: $(uname -s)"
      exit 1
      ;;
  esac

  if ! have vim; then
    err "Vim installation did not produce a usable \`vim\` binary."
    exit 1
  fi

  local version
  version="$(get_vim_version)"
  log "Vim installed: $(vim --version 2>/dev/null | head -n1)"

  if [[ -n "$version" ]] && ! version_ge "$version" "$MIN_VIM_VERSION"; then
    warn "Your Vim (${version}) is older than ${MIN_VIM_VERSION}."
    warn "For the best experience, compile Vim from source."
  fi
}

main "$@"
