#!/usr/bin/env bash
# setup-ddcutil-fedora.sh
# Installs and configures ddcutil on Fedora without requiring full sudo session.

set -euo pipefail

log()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

SUDO="sudo"
if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  SUDO=""
fi

INVOKING_USER="${SUDO_USER-$(id -un)}"
USER_HOME="$(getent passwd "$INVOKING_USER" | cut -d: -f6)"

is_fedora() {
  [[ -f /etc/os-release ]] && . /etc/os-release && [[ "$ID" == "fedora" || "$ID_LIKE" =~ fedora ]]
}

install_ddcutil() {
  log "Installing ddcutil and i2c-tools..."
  $SUDO dnf -y install ddcutil i2c-tools || {
    err "Failed to install packages. Check network or repositories."
    exit 1
  }
}

setup_i2c_group() {
  log "Ensuring 'i2c' group exists..."
  if ! getent group i2c >/dev/null; then
    $SUDO groupadd -r i2c
  fi

  log "Adding user '${INVOKING_USER}' to group 'i2c'..."
  if ! id -nG "$INVOKING_USER" | grep -qw i2c; then
    $SUDO usermod -aG i2c "$INVOKING_USER"
    warn "User added to group 'i2c'. You must log out/in for changes to apply."
  fi
}

load_i2c_modules() {
  log "Loading kernel module i2c-dev..."
  if ! lsmod | grep -q '^i2c_dev'; then
    $SUDO modprobe i2c-dev || warn "Could not load i2c-dev (maybe not built-in?)."
  fi

  log "Ensuring i2c-dev loads on boot..."
  $SUDO mkdir -p /etc/modules-load.d
  echo "i2c-dev" | $SUDO tee /etc/modules-load.d/i2c-dev.conf >/dev/null
}

setup_udev_rules() {
  local rule_file="/etc/udev/rules.d/45-ddcutil-i2c.rules"
  log "Writing udev rule to ${rule_file}..."
  $SUDO bash -c "cat > '${rule_file}'" <<'RULES'
# Allow users in group 'i2c' to access I2C devices
SUBSYSTEM=="i2c-dev", GROUP="i2c", MODE="0660"
RULES

  log "Reloading udev rules..."
  $SUDO udevadm control --reload-rules
  $SUDO udevadm trigger --subsystem-match=i2c-dev || true

  if compgen -G "/dev/i2c-*" >/dev/null; then
    log "Applying group/permission fixes to existing /dev/i2c-* devices..."
    for dev in /dev/i2c-*; do
      $SUDO chgrp i2c "$dev" || true
      $SUDO chmod 0660 "$dev" || true
    done
  else
    warn "No /dev/i2c-* devices found yet. Rules will apply when hardware is active."
  fi
}

summary() {
  cat <<'EOF'

-------------------------------------------------------------
✅ DDCutil setup complete.

Next steps:
  - Log out and back in (or reboot) so group changes take effect.
  - Run:    ddcutil detect
  - If no displays are found, ensure kernel I2C controller modules are loaded:
      sudo modprobe i2c-i801   # for Intel chipsets
      sudo modprobe i2c-piix4  # for AMD
  - Then recheck with: ddcutil detect
-------------------------------------------------------------
EOF
}

main() {
  if ! is_fedora; then
    warn "This system may not be Fedora-based. Proceeding anyway."
  fi

  install_ddcutil
  setup_i2c_group
  load_i2c_modules
  setup_udev_rules
  summary
}

main "$@"
