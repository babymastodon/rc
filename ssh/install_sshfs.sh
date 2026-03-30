#!/usr/bin/env bash
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  printf 'Homebrew not found. Install Homebrew first: https://brew.sh/\n' >&2
  exit 1
fi

brew tap macos-fuse-t/homebrew-cask
brew install fuse-t
brew install fuse-t-sshfs
