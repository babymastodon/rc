#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Dropbox headless + CLI uninstaller for Fedora (x86_64)
# Removes:
#   - Systemd user unit (XDG_CONFIG_HOME/systemd/user/dropbox.service)
#   - Dropbox daemon binaries (XDG_DATA_HOME/dropbox/dist)
#   - Dropbox CLI script (~/.local/bin/dropbox)
# Leaves intact:
#   - Your synced data (~/Dropbox)
#   - Dropbox account info in ~/.dropbox (so you can re-install easily)
# ============================================================

log()   { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

dropbox_is_running() {
  "$dropbox_cli_path" running >/dev/null 2>&1 || pgrep -f "$dropbox_daemon_path" >/dev/null 2>&1
}

# ----- XDG defaults -----
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Our paths (XDG-aware)
dropbox_daemon_dir="$XDG_DATA_HOME/dropbox/dist"
dropbox_daemon_path="$dropbox_daemon_dir/dropboxd"
dropbox_cli_path="$HOME/.local/bin/dropbox"
systemd_user_dir="$XDG_CONFIG_HOME/systemd/user"
service_file="$systemd_user_dir/dropbox.service"

stop_and_disable_service() {
  if systemctl --user >/dev/null 2>&1; then
    if systemctl --user status dropbox.service >/dev/null 2>&1; then
      log "Stopping user service: dropbox.service"
      systemctl --user stop dropbox.service || warn "Failed to stop dropbox.service"
    fi
    log "Disabling user service: dropbox.service"
    systemctl --user disable dropbox.service >/dev/null 2>&1 || warn "Failed to disable dropbox.service"
    if [[ -f "$service_file" ]]; then
      log "Removing service file: $service_file"
      rm -f "$service_file"
      systemctl --user daemon-reload || warn "systemctl --user daemon-reload failed."
    fi
  else
    warn "systemd user instance not detected."
  fi

  if [[ -x "$dropbox_cli_path" ]]; then
    log "Attempting to stop Dropbox via CLI…"
    "$dropbox_cli_path" stop || warn "Dropbox CLI stop returned non-zero."
  fi

  # Final guard: kill the daemon if still running
  if dropbox_is_running; then
    warn "Dropbox still appears to be running; terminating dropboxd process."
    pkill -f "$dropbox_daemon_path" >/dev/null 2>&1 || warn "Failed to terminate dropboxd process."
  fi
}

remove_daemon() {
  if [[ -d "$dropbox_daemon_dir" ]]; then
    log "Removing Dropbox daemon directory: $dropbox_daemon_dir"
    rm -rf "$dropbox_daemon_dir"
  else
    log "Dropbox daemon directory not found (nothing to remove): $dropbox_daemon_dir"
  fi
}

remove_cli() {
  if [[ -e "$dropbox_cli_path" ]]; then
    log "Removing Dropbox CLI script: $dropbox_cli_path"
    rm -f "$dropbox_cli_path"
  else
    log "Dropbox CLI script not found (nothing to remove): $dropbox_cli_path"
  fi
}

log "=== Dropbox headless + CLI uninstall (Fedora, XDG-aware) ==="

stop_and_disable_service
remove_daemon
remove_cli

log "Uninstall complete."
log "User data has been left intact at: $HOME/Dropbox"
log "Account metadata remains in: $HOME/.dropbox (remove manually if desired)"

exit 0
