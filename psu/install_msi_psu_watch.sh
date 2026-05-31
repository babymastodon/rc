#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ----- helpers -----
log()   { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

VID="0db0"
PID="c9eb"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
BIN_NAME="msi-psu-watch"
SRC="$SCRIPT_DIR/$BIN_NAME"
DEST="$BIN_DIR/$BIN_NAME"

detect_linux() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    err "msi-psu-watch only supports Linux hidraw devices."
    exit 1
  fi
}

require_command() {
  local cmd="$1"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    err "Missing required command: $cmd"
    exit 1
  fi
}

detect_psu() {
  local dev vendor product manufacturer name

  for dev in /sys/bus/usb/devices/*; do
    [[ -f "$dev/idVendor" && -f "$dev/idProduct" ]] || continue

    vendor="$(<"$dev/idVendor")"
    product="$(<"$dev/idProduct")"
    [[ "${vendor,,}" == "$VID" && "${product,,}" == "$PID" ]] || continue

    manufacturer="$(cat "$dev/manufacturer" 2>/dev/null || true)"
    name="$(cat "$dev/product" 2>/dev/null || true)"

    log "Detected MSI PSU USB device: $VID:$PID at $dev"
    if [[ -n "$manufacturer$name" ]] && LC_ALL=C grep -Eq '^[ -~]+$' <<<"$manufacturer$name"; then
      log "Device name: ${manufacturer:-MSI} ${name:-MEG Ai1600T}"
    fi
    return 0
  done

  return 1
}

print_detection_error() {
  err "MSI MEG Ai1600T PSU USB device was not detected; not installing $BIN_NAME."
  printf '\nExpected USB device:\n' >&2
  printf '  %s:%s Micro-Star International MSI MEG Ai1600T\n' "$VID" "$PID" >&2
  printf '\nCheck:\n' >&2
  printf '  - The PSU USB cable is connected to the motherboard or rear I/O.\n' >&2
  printf '  - The system can see the device with `lsusb | grep -i "0db0:c9eb"`.\n' >&2
  printf '  - The kernel has created a hidraw node under /dev/hidraw*.\n' >&2
  printf '\nInstall skipped; no files were written to %s.\n' "$BIN_DIR" >&2
}

install_script() {
  if [[ ! -f "$SRC" ]]; then
    err "Missing source script: $SRC"
    exit 1
  fi

  mkdir -p "$BIN_DIR"
  chmod +x "$SRC"

  if [[ -e "$DEST" || -L "$DEST" ]]; then
    if [[ -L "$DEST" ]]; then
      local target
      target="$(readlink "$DEST")"
      if [[ "$target" == "$SRC" ]]; then
        log "Link already correct: $DEST -> $SRC"
      else
        warn "Link exists but wrong target ($target), fixing..."
        rm -f "$DEST"
        ln -s "$SRC" "$DEST"
        log "Fixed link: $DEST -> $SRC"
      fi
    else
      err "Destination exists and is not a symlink: $DEST"
      err "Remove it manually if you want this installer to manage that command."
      exit 1
    fi
  else
    ln -s "$SRC" "$DEST"
    log "Linked: $DEST -> $SRC"
  fi

  if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    warn "$BIN_DIR is not currently in PATH."
    warn "Add it to your shell config or run $DEST directly."
  fi
}

print_device_access_note() {
  if [[ -e /dev/msi-ai1600t ]]; then
    log "udev symlink present: /dev/msi-ai1600t"
  else
    warn "/dev/msi-ai1600t is not present."
    warn "Install the udev rule from $SCRIPT_DIR/README.md if msi-psu-watch cannot open the device."
  fi
}

detect_linux
require_command python3

if ! detect_psu; then
  print_detection_error
  exit 1
fi

install_script
print_device_access_note
log "Done."
