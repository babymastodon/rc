#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Dropbox headless + CLI installer for Fedora (x86_64)
# XDG-aware:
#   - Daemon in   : $XDG_DATA_HOME/dropbox/dist
#   - systemd unit: $XDG_CONFIG_HOME/systemd/user/dropbox.service
#   - CLI script  : ~/.local/bin/dropbox
#
# - Installs Dropbox daemon (headless)
# - Installs CLI
# - Links this machine (interactive)
# - Configures selective sync so ONLY "<DropboxRoot>/Documents" is synced
#   by excluding every other top-level folder.
#
# NOTE:
# - Dropbox itself still uses ~/.dropbox and ~/Dropbox internally.
# - Selective sync is exclude-based; this script excludes all top-level
#   folders except "Documents" at the time it runs.
# ============================================================

# ----- helpers -----
log()   { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

need_sudo() { if [[ $EUID -ne 0 ]]; then echo "sudo"; fi; }
SUDO="$(need_sudo || true)"

maybe_link() {
  local src="$1" dest="$2"

  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ -L "$dest" ]]; then
      local target
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
      warn "Exists and not a link: $dest (skipping)"
    fi
  else
    ln -s "$src" "$dest"
    log "Linked: $dest -> $src"
  fi
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

# NOTE: Dropbox itself still writes here; this is NOT XDG-compliant,
# but we can't change what Dropbox does internally.
dropbox_info_json="$HOME/.dropbox/info.json"

# ----- sanity checks -----

# Ensure DNF exists (Fedora/RHEL family)
if ! command -v dnf >/dev/null 2>&1; then
  err "This script expects Fedora (dnf not found)."
  exit 1
fi

# Ensure 64-bit architecture (Dropbox daemon is 64-bit only)
ARCH="$(uname -m)"
if [[ "$ARCH" != "x86_64" ]]; then
  err "Dropbox headless binary used by this script is only available for x86_64. Detected: $ARCH"
  exit 1
fi

# Ensure basic tools exist (wget, tar, python3)
if ! command -v wget >/dev/null 2>&1; then
  log "Installing wget…"
  $SUDO dnf -y install wget || { err "Failed to install wget via dnf."; exit 1; }
fi

if ! command -v tar >/dev/null 2>&1; then
  log "Installing tar…"
  $SUDO dnf -y install tar || { err "Failed to install tar via dnf."; exit 1; }
fi

if ! command -v python3 >/dev/null 2>&1; then
  log "Installing python3…"
  $SUDO dnf -y install python3 || { err "Failed to install python3 via dnf."; exit 1; }
fi

# ----- helpers for Dropbox state -----

is_dropbox_linked() {
  [[ -f "$dropbox_info_json" ]]
}

get_dropbox_root() {
  # Try to parse ~/.dropbox/info.json for "personal" path, else fall back to ~/Dropbox
  if [[ -f "$dropbox_info_json" ]]; then
    local path
    path="$(tr -d '\n' <"$dropbox_info_json" \
      | sed -n 's/.*"personal":[^}]*"path":[[:space:]]*"\([^"]*\)".*/\1/p' || true)"
    if [[ -n "$path" ]]; then
      printf '%s\n' "$path"
      return 0
    fi
  fi
  printf '%s\n' "$HOME/Dropbox"
}

# ----- install daemon (XDG_DATA_HOME) -----

install_dropbox_daemon() {
  if [[ -x "$dropbox_daemon_path" ]]; then
    log "Dropbox daemon already installed at $dropbox_daemon_path"
    return
  fi

  log "Downloading Dropbox daemon (64-bit Linux)…"

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

  if ! wget -O "$tmpdir/dropbox.tgz" "https://www.dropbox.com/download?plat=lnx.x86_64"; then
    err "Failed to download Dropbox daemon archive."
    exit 1
  fi

  mkdir -p "$dropbox_daemon_dir"
  # Extract into temp, then move contents of .dropbox-dist into XDG_DATA_HOME path
  tar -xzf "$tmpdir/dropbox.tgz" -C "$tmpdir"

  if [[ ! -d "$tmpdir/.dropbox-dist" ]]; then
    err "Expected .dropbox-dist directory not found in archive."
    exit 1
  fi

  # Move (or copy) contents, preserving attributes
  cp -a "$tmpdir/.dropbox-dist/." "$dropbox_daemon_dir/"

  if [[ ! -x "$dropbox_daemon_path" ]]; then
    err "Dropbox daemon not found at $dropbox_daemon_path after install."
    exit 1
  fi

  log "Dropbox daemon installed at $dropbox_daemon_path"
}

# ----- install CLI (user bin) -----

install_dropbox_cli() {
  if [[ -x "$dropbox_cli_path" ]]; then
    log "Dropbox CLI already installed at $dropbox_cli_path"
    return
  fi

  log "Installing Dropbox CLI script…"
  mkdir -p "$HOME/.local/bin"

  local cli_url="https://www.dropbox.com/download?dl=packages/dropbox.py"

  if ! wget -O "$dropbox_cli_path" "$cli_url"; then
    err "Failed to download Dropbox CLI from $cli_url"
    exit 1
  fi

  chmod +x "$dropbox_cli_path"
  log "Dropbox CLI installed as $dropbox_cli_path"

  if [[ ":${PATH}:" != *":${HOME}/.local/bin:"* ]]; then
    warn "~/.local/bin is not in PATH for this session.
  Consider adding: 'export PATH=\$HOME/.local/bin:\$PATH' to your shell rc."
  fi
}

# ----- linking flow -----

link_dropbox_if_needed() {
  if is_dropbox_linked; then
    log "Dropbox already appears to be linked (found $dropbox_info_json)."
    return
  fi

  if [[ ! -x "$dropbox_daemon_path" ]]; then
    err "Dropbox daemon is missing at $dropbox_daemon_path, cannot link."
    exit 1
  fi

  log "Linking this machine to your Dropbox account (headless)…"
  "$dropbox_daemon_path" &
  local db_pid=$!
  log "Temporary Dropbox daemon started (PID $db_pid)."

  cat <<'EOF'
========================================================================
ACTION REQUIRED:

  1. Watch the output above from "dropboxd". You should see a line like:

       Please visit https://www.dropbox.com/cli_link_nonce?nonce=… to link this device.

  2. Open that URL in a browser on ANY machine and complete the linking
     process with your Dropbox account.

  3. Once Dropbox says "This computer is now linked", return here and
     press ENTER to continue.
========================================================================
EOF

  read -r _

  if kill "$db_pid" 2>/dev/null; then
    log "Stopped temporary Dropbox daemon (PID $db_pid)."
  fi
  wait "$db_pid" 2>/dev/null || true

  if is_dropbox_linked; then
    log "Dropbox appears linked (found $dropbox_info_json)."
  else
    warn "Could not find $dropbox_info_json. Dropbox may NOT be fully linked yet."
    warn "You can re-run this script after confirming the link in your browser."
  fi
}

ensure_daemon_running_via_cli() {
  if ! "$dropbox_cli_path" running >/dev/null 2>&1; then
    log "Starting Dropbox daemon via CLI…"
    if ! "$dropbox_cli_path" start -i; then
      warn "Failed to start Dropbox daemon via CLI. Continuing, but commands may fail."
    fi
  else
    log "Dropbox daemon already running."
  fi
}

# ----- selective sync: only Documents -----

configure_selective_sync_documents_only() {
  local root
  root="$(get_dropbox_root)"

  log "Using Dropbox root: $root"

  if [[ ! -d "$root" ]]; then
    warn "Dropbox root directory '$root' does not exist yet."
    warn "Creating it locally so Documents can be synced…"
    mkdir -p "$root"
  fi

  mkdir -p "$root/Documents"
  log "Ensured '$root/Documents' exists."

  pushd "$root" >/dev/null

  ensure_daemon_running_via_cli

  log "Configuring selective sync: excluding all top-level folders except 'Documents'…"
  mapfile -t top_dirs < <(find . -mindepth 1 -maxdepth 1 -type d -printf '%P\n' | sort)

  if ((${#top_dirs[@]} == 0)); then
    warn "No top-level folders found in '$root' yet (maybe still syncing?)."
  fi

  for d in "${top_dirs[@]}"; do
    if [[ "$d" == "Documents" ]]; then
      log "Keeping folder synced: $root/$d"
      continue
    fi

    if [[ "$d" == ".dropbox.cache" ]]; then
      log "Skipping internal folder: $root/$d"
      continue
    fi

    log "Excluding folder from sync: $root/$d"
    if ! "$dropbox_cli_path" exclude add "$root/$d"; then
      warn "Failed to exclude '$root/$d' (command returned non-zero)."
    fi
  done

  log "Current exclusion list (for verification):"
  "$dropbox_cli_path" exclude list || warn "Could not list exclusions."

  popd >/dev/null
}

# ----- systemd user service (XDG_CONFIG_HOME) -----

install_systemd_user_service() {
  log "Installing user systemd service for Dropbox daemon (XDG_CONFIG_HOME)…"

  local systemd_user_dir="$XDG_CONFIG_HOME/systemd/user"
  mkdir -p "$systemd_user_dir"

  local service_file="$systemd_user_dir/dropbox.service"

  cat >"$service_file" <<EOF
[Unit]
Description=Dropbox Daemon (user)
After=network-online.target

[Service]
Type=simple
ExecStart=$dropbox_daemon_path
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=default.target
EOF

  log "Wrote user systemd unit: $service_file"

  if systemctl --user >/dev/null 2>&1; then
    log "Reloading user systemd daemon and enabling Dropbox service…"
    systemctl --user daemon-reload || warn "systemctl --user daemon-reload failed."
    systemctl --user enable --now dropbox.service || \
      warn "Failed to enable/start dropbox.service (check logs with: systemctl --user status dropbox.service)"
    systemctl --user status dropbox.service --no-pager --full || true
  else
    warn "systemd user instance not detected. To run user services across logouts:
  loginctl enable-linger \"$USER\"

Then re-run:
  systemctl --user daemon-reload
  systemctl --user enable --now dropbox.service"
  fi
}

# ----- main flow -----

log "=== Dropbox headless + CLI setup (Fedora, XDG-aware) ==="

install_dropbox_daemon
install_dropbox_cli
link_dropbox_if_needed
configure_selective_sync_documents_only
install_systemd_user_service

log "All done.
- Dropbox daemon installed in: $dropbox_daemon_dir
- CLI installed as         : $dropbox_cli_path
- Machine linked (if you completed the browser step).
- Selective sync: ONLY 'Documents' (top-level) kept in sync.
- User systemd service: dropbox.service at $XDG_CONFIG_HOME/systemd/user."

exit 0

