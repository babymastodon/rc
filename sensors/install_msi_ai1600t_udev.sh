#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
RULE_PATH="/etc/udev/rules.d/70-msi-ai1600t.rules"
RULE='SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0db0", ATTRS{idProduct}=="c9eb", TAG+="uaccess", SYMLINK+="msi-ai1600t"'

log()   { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

root_install() {
  install -d /etc/udev/rules.d
  printf '%s\n' "$RULE" >"$RULE_PATH"
  udevadm control --reload-rules
  udevadm trigger
}

if [[ "${1:-}" == "--root-install" ]]; then
  root_install
  exit 0
fi

if [[ "$(uname -s)" != "Linux" ]]; then
  err "install_msi_ai1600t_udev.sh only supports Linux."
  exit 1
fi

if command -v pkexec >/dev/null 2>&1; then
  pkexec "$SCRIPT_PATH" --root-install
else
  sudo "$SCRIPT_PATH" --root-install
fi

log "Installed $RULE_PATH"
log "Reconnect the PSU USB cable if /dev/msi-ai1600t is not created immediately."
