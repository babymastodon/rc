#!/usr/bin/env bash
set -euo pipefail

# ----- helpers -----
log()   { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }
need_sudo() { if [[ $EUID -ne 0 ]]; then echo "sudo"; fi; }
SUDO="$(need_sudo || true)"

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

# ----- ensure curl and ImageMagick (for icon conversion) -----
if ! command -v curl >/dev/null 2>&1; then
  log "Installing curl…"
  $SUDO dnf -y install curl
else
  log "curl already present."
fi

if ! command -v magick >/dev/null 2>&1; then
  log "Installing ImageMagick (for webp->png)…"
  $SUDO dnf -y install ImageMagick || {
    err "Failed to install ImageMagick."
    exit 1
  }
else
  log "ImageMagick already present: $(magick -version | head -n1)"
fi

# (Optional) desktop-file-utils for update-desktop-database
if ! command -v update-desktop-database >/dev/null 2>&1; then
  log "Installing desktop-file-utils…"
  $SUDO dnf -y install desktop-file-utils || true
fi

# ----- install yazi if missing (via cargo, using your chosen crate) -----
have_yazi() {
  command -v yazi >/dev/null 2>&1 || command -v yazi-fm >/dev/null 2>&1
}

if ! have_yazi; then
  log "Installing Yazi via cargo (crate: yazi-build)…"
  cargo install yazi-build --locked || {
    err "cargo install yazi-build failed."
    exit 1
  }
else
  log "Yazi already installed: $(
    (yazi --version 2>/dev/null || yazi-fm --version 2>/dev/null || echo 'version lookup skipped') | head -n1
  )"
fi

# ----- link configs -----
log "Linking Yazi configuration…"
mkdir -p "$HOME/.config/yazi/"
ln -sf "$PWD/yazi.toml" "$HOME/.config/yazi/yazi.toml"

mkdir -p "$HOME/.local/share/applications/"
ln -sf "$PWD/yazi.desktop" "$HOME/.local/share/applications/yazi.desktop"

# ----- icon install -----
log "Installing Yazi icon…"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
ICON_TMP="$(mktemp)"
mkdir -p "$ICON_DIR"
curl -fsSL "https://yazi-rs.github.io/webp/logo.webp" -o "$ICON_TMP"
magick "$ICON_TMP" -resize 256x256 "$ICON_DIR/yazi.png"
rm -f "$ICON_TMP"
gtk-update-icon-cache "$HOME/.local/share/icons/hicolor" -f 2>/dev/null || true
log "✅ Installed: $ICON_DIR/yazi.png (use Icon=yazi in your .desktop)"

# ----- desktop DB update -----
update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true

log "Done."

