#!/usr/bin/env bash
set -euo pipefail

# ----- helpers -----
log()   { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }
need_sudo() { if [[ $EUID -ne 0 ]]; then echo "sudo"; fi; }
SUDO="$(need_sudo || true)"

# robust symlink creator
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
      local backup="${dest}.bak"
      warn "Exists and not a link: $dest (backing up to $backup and replacing)"
      mv -f "$dest" "$backup"
      ln -s "$src" "$dest"
      log "Linked: $dest -> $src"
    fi
  else
    ln -s "$src" "$dest"
    log "Linked: $dest -> $src"
  fi
}

# Ensure DNF exists (Fedora/RHEL family)
if ! command -v dnf >/dev/null 2>&1; then
  err "This script expects Fedora (dnf not found)."
  exit 1
fi

# ----- ensure cargo (and rustc) -----
if ! command -v cargo >/dev/null 2>&1; then
  log "Installing Cargo (and Rust toolchain) via DNF…"
  $SUDO dnf -y install cargo rustc || {
    err "Failed to install cargo/rustc via DNF."
    exit 1
  }
else
  log "Cargo already present: $(cargo --version)"
fi

# Make sure ~/.cargo/bin is in PATH for this session
export PATH="$HOME/.cargo/bin:$PATH"

# ----- install MPD if missing -----
is_rpmfusion_enabled() {
  dnf repolist --enabled 2>/dev/null | grep -qi 'rpmfusion'
}

is_rpmfusion_free_enabled() {
  dnf repolist --enabled 2>/dev/null | grep -qi 'rpmfusion-free'
}

mpd_available() {
  dnf -q list --available mpd >/dev/null 2>&1
}

if ! command -v mpd >/dev/null 2>&1 && ! rpm -q mpd >/dev/null 2>&1; then
  if ! mpd_available; then
    FEDVER="$($SUDO rpm -E %fedora)"
    if ! is_rpmfusion_free_enabled; then
      log "Enabling RPM Fusion Free…"
      $SUDO dnf -y install \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDVER}.noarch.rpm"
      $SUDO dnf -y makecache
    else
      log "RPM Fusion Free already enabled."
    fi
  fi
  log "Installing MPD…"
  $SUDO dnf -y install mpd || {
    err "Failed to install MPD via DNF."
    exit 1
  }
else
  log "MPD already installed: $(mpd --version | head -n1 || echo 'version lookup skipped')"
fi

# ----- install rmpc if missing -----
if ! command -v rmpc >/dev/null 2>&1; then
  log "Installing rmpc via cargo…"
  cargo install rmpc --locked || {
    err "cargo install rmpc failed."
    exit 1
  }
else
  log "rmpc already installed: $(echo 'version lookup skipped')"
fi

# ----- link configs -----
log "Linking configs…"
mkdir -p "$HOME/.config/mpd/" "$HOME/.local/share/mpd/"
maybe_link "$PWD/mpd.conf" "$HOME/.config/mpd/mpd.conf"

mkdir -p "$HOME/.config/rmpc/"
maybe_link "$PWD/config.ron" "$HOME/.config/rmpc/config.ron"

mkdir -p "$HOME/.local/share/applications/"
maybe_link "$PWD/rmpc.desktop" "$HOME/.local/share/applications/rmpc.desktop"

# ----- systemd user service (AFTER linking configs) -----
if systemctl --user 2>/dev/null >/dev/null; then
  log "Enabling & starting user mpd.service…"
  systemctl --user daemon-reload || warn "systemctl --user daemon-reload failed."
  systemctl --user enable mpd.service || warn "Failed to enable user mpd.service."
  systemctl --user start mpd.service || warn "Failed to start user mpd.service."
else
  warn "systemd user instance not detected. If needed, run:
    loginctl enable-linger \"$USER\"
  and re-run this script (or start mpd manually)."
fi

# ----- icon install -----
log "Installing rmpc icon…"
ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
ICON_PATH="$ICON_DIR/rmpc.svg"
mkdir -p "$ICON_DIR"
cp $PWD/rmpc.svg "$ICON_PATH"
gtk-update-icon-cache "$HOME/.local/share/icons/hicolor" -f 2>/dev/null || true
log "✅ Installed icon at $ICON_PATH"

# ----- desktop DB update -----
update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
log "Done."
