#!/usr/bin/env bash
set -euo pipefail

log()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*" >&2; }
err()  { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  err "This script is for macOS only."
  exit 1
fi

BREW_BIN="${BREW_BIN:-}"
if [[ -z "$BREW_BIN" ]]; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    BREW_BIN="/opt/homebrew/bin/brew"
  elif [[ -x /usr/local/bin/brew ]]; then
    BREW_BIN="/usr/local/bin/brew"
  else
    err "Homebrew is required. Install it first from https://brew.sh"
    exit 1
  fi
fi

BREW_PREFIX="$("$BREW_BIN" --prefix)"
BASH_BIN="${BREW_PREFIX}/bin/bash"

if [[ ! -x "$BASH_BIN" ]]; then
  log "Installing Bash with Homebrew..."
  "$BREW_BIN" install bash
fi

if [[ ! -x "$BASH_BIN" ]]; then
  err "Bash was not found at $BASH_BIN after Homebrew install."
  exit 1
fi

if ! grep -Fxq "$BASH_BIN" /etc/shells; then
  log "Adding $BASH_BIN to /etc/shells..."
  printf '%s\n' "$BASH_BIN" | sudo tee -a /etc/shells >/dev/null
else
  log "$BASH_BIN is already listed in /etc/shells."
fi

current_shell="$(dscl . -read "/Users/${USER}" UserShell 2>/dev/null | awk '{print $2}' || true)"
if [[ "$current_shell" == "$BASH_BIN" ]]; then
  log "Default shell is already $BASH_BIN."
  exit 0
fi

log "Changing default shell to $BASH_BIN..."
chsh -s "$BASH_BIN"
log "Default shell updated."
warn "Fully quit and reopen your terminal app to start using Bash."
warn "If you use Ghostty, a new window is not enough; quit the app completely and open it again."
