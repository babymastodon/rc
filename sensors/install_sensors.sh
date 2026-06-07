#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()   { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
BIN_NAMES=("hwstat")
LEGACY_BIN_NAMES=("mobo-watch" "msi-psu-watch")

if [[ "$(uname -s)" != "Linux" ]]; then
  err "sensor watchers only support Linux hwmon and hidraw devices."
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  err "Missing required command: python3"
  exit 1
fi

mkdir -p "$BIN_DIR"

for bin_name in "${BIN_NAMES[@]}"; do
  src="$SCRIPT_DIR/$bin_name"
  dest="$BIN_DIR/$bin_name"

  if [[ ! -f "$src" ]]; then
    err "Missing source script: $src"
    exit 1
  fi

  chmod +x "$src"

  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ -L "$dest" ]]; then
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
      err "Destination exists and is not a symlink: $dest"
      err "Remove it manually if you want this installer to manage that command."
      exit 1
    fi
  else
    ln -s "$src" "$dest"
    log "Linked: $dest -> $src"
  fi
done

for bin_name in "${LEGACY_BIN_NAMES[@]}"; do
  dest="$BIN_DIR/$bin_name"
  if [[ ! -L "$dest" ]]; then
    if [[ -e "$dest" ]]; then
      warn "Legacy command exists but is not a symlink, leaving it alone: $dest"
    fi
    continue
  fi

  target="$(readlink "$dest")"
  case "$target" in
    "$SCRIPT_DIR/$bin_name"|"$SCRIPT_DIR/mobo-watch"|"$SCRIPT_DIR"/../psu/"$bin_name"|*/code/rc/sensors/"$bin_name"|*/code/rc/sensors/mobo-watch|*/code/rc/psu/"$bin_name")
      rm -f "$dest"
      log "Removed legacy link: $dest -> $target"
      ;;
    *)
      warn "Legacy command points somewhere else, leaving it alone: $dest -> $target"
      ;;
  esac
done

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  warn "$BIN_DIR is not currently in PATH."
  warn "Add it to your shell config or run $BIN_DIR/hwstat directly."
fi

log "Current sensor check:"
"$SCRIPT_DIR/hwstat" --check || true
log "Done."
