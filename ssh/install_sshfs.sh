#!/usr/bin/env bash
set -euo pipefail

need_sudo() {
  if [[ $EUID -ne 0 ]]; then
    echo "sudo"
  fi
}

SUDO="$(need_sudo || true)"
os="$(uname -s)"

case "$os" in
  Darwin)
    if ! command -v brew >/dev/null 2>&1; then
      printf 'Homebrew not found. Install Homebrew first: https://brew.sh/\n' >&2
      exit 1
    fi

    brew tap macos-fuse-t/homebrew-cask
    brew install fuse-t
    brew install fuse-t-sshfs
    ;;
  Linux)
    if command -v dnf >/dev/null 2>&1; then
      $SUDO dnf install -y fuse-sshfs
    elif command -v apt-get >/dev/null 2>&1; then
      $SUDO apt-get update
      $SUDO apt-get install -y sshfs
    elif command -v pacman >/dev/null 2>&1; then
      $SUDO pacman -Sy --noconfirm sshfs
    else
      printf 'Unsupported Linux package manager. Install sshfs manually.\n' >&2
      exit 1
    fi
    ;;
  *)
    printf 'Unsupported OS: %s\n' "$os" >&2
    exit 1
    ;;
esac
