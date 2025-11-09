#!/usr/bin/env bash
# setup-ddcutil-fedora.sh
# Installs ddcutil on Fedora and configures group/permissions for /dev/i2c-*
# Run with: sudo bash setup-ddcutil-fedora.sh

set -euo pipefail

#----- helpers ---------------------------------------------------------------#
log() { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root (use sudo)."
    exit 1
  fi
}

detect_user() {
  # Prefer the user who invoked sudo; fall back to current user.
  if [[ -n "${SUDO_USER-}" && "${SUDO_USER}" != "root" ]]; then
    INVOKING_USER="${SUDO_USER}"
  else
    INVOKING_USER="${USER}"
  fi
  if [[ -z "${INVOKING_USER}" || "${INVOKING_USER}" == "root" ]]; then
    warn "Could not determine a non-root invoking user; using 'root' (no group membership changes will apply)."
  fi
}

is_fedora() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    [[ "${ID}" == "fedora" ]] || [[ "${ID_LIKE-}" == *"fedora"* ]]
  else
    return 1
  fi
}

#----- main steps ------------------------------------------------------------#
require_root
detect_user

if ! is_fedora; then
  warn "This system does not appear to be Fedora-based. Proceeding anyway, but 'dnf' must be available."
fi

log "Refreshing package metadata and installing ddcutil..."
dnf -y install ddcutil i2c-tools >/dev/null 2>&1 || dnf -y install ddcutil i2c-tools

# Create 'i2c' group if needed (system group)
if getent group i2c >/dev/null 2>&1; then
  log "Group 'i2c' already exists."
else
  log "Creating group 'i2c'..."
  groupadd -r i2c
fi

# Add invoking user to i2c group (if not root)
if [[ "${INVOKING_USER}" != "root" ]]; then
  if id -nG "${INVOKING_USER}" | tr ' ' '\n' | grep -qx i2c; then
    log "User '${INVOKING_USER}' is already in group 'i2c'."
  else
    log "Adding user '${INVOKING_USER}' to group 'i2c'..."
    usermod -aG i2c "${INVOKING_USER}"
    ADDED_TO_GROUP=1
  fi
fi

# Ensure i2c-dev kernel module is loaded now and at boot
log "Loading kernel module 'i2c-dev' (if not already loaded)..."
if ! lsmod | grep -q '^i2c_dev'; then
  modprobe i2c-dev || true
fi

log "Ensuring 'i2c-dev' loads on boot..."
mkdir -p /etc/modules-load.d
echo "i2c-dev" >/etc/modules-load.d/i2c-dev.conf

# Udev rules for /dev/i2c-* so 'i2c' group can access them
UDEV_RULE_FILE="/etc/udev/rules.d/45-ddcutil-i2c.rules"
log "Writing udev rule to ${UDEV_RULE_FILE}..."
cat > "${UDEV_RULE_FILE}" <<'RULES'
# Allow users in group 'i2c' to access I2C device nodes for ddcutil
SUBSYSTEM=="i2c-dev", GROUP="i2c", MODE="0660"
RULES

# Reload udev rules and apply to existing devices
log "Reloading and triggering udev rules..."
udevadm control --reload-rules
udevadm trigger --subsystem-match=i2c-dev || true

# Also fix current device nodes immediately (in case udev trigger missed any)
if compgen -G "/dev/i2c-*" > /dev/null; then
  log "Applying permissions to existing /dev/i2c-* nodes..."
  chgrp i2c /dev/i2c-* || true
  chmod 0660 /dev/i2c-* || true
else
  warn "No /dev/i2c-* devices found right now. That's okay—rules will apply when devices appear."
fi

# (Optional) Load common platform I2C bus drivers (harmless if not present)
# Intel LPC/I2C host controller is often i2c-i801; AMD families may use i2c-piix4.
# We don't force-load them, but you can uncomment if needed:
# modprobe i2c-i801 2>/dev/null || true
# modprobe i2c-piix4 2>/dev/null || true

# Final message and next steps
log "Configuration complete."

if [[ "${INVOKING_USER}" != "root" ]]; then
  if [[ "${ADDED_TO_GROUP-}" == "1" ]]; then
    warn "You must log out and log back in (or reboot) for new group membership to take effect for '${INVOKING_USER}'."
  fi
fi

# Quick smoke test suggestion
echo
log "Optional: After re-login, test with:"
echo "  ddcutil detect"
echo

