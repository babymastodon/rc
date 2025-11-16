i#!/usr/bin/env bash
set -euo pipefail

# ----- helpers -----
log()   { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }
need_sudo() { if [[ $EUID -ne 0 ]]; then echo "sudo"; fi; }

OS=""
PKG_MGR=""
SUDO=""
APT_UPDATED=0
GNOME_DESKTOP=0

detect_os() {
  case "${OSTYPE:-unknown}" in
    darwin*)
      OS="mac"
      PKG_MGR="brew"
      SUDO=""   # NEVER use sudo with brew
      if ! command -v brew >/dev/null 2>&1; then
        err "Homebrew not found. Install from https://brew.sh first."
        exit 1
      fi
      ;;
    linux-gnu*|linux*)
      OS="linux"
      if command -v dnf >/dev/null 2>&1; then
        PKG_MGR="dnf"
        SUDO="$(need_sudo || true)"
      elif command -v apt-get >/dev/null 2>&1; then
        PKG_MGR="apt"
        SUDO="$(need_sudo || true)"
      else
        err "Supported Linux distros: Fedora/RHEL (dnf) or Debian/Ubuntu (apt-get not found)."
        exit 1
      fi
      ;;
    *)
      err "Unsupported OS: $OSTYPE"
      exit 1
      ;;
  esac

  log "Detected OS: $OS (pkg manager: $PKG_MGR)"
}

detect_gnome() {
  if [[ "$OS" != "linux" ]]; then
    GNOME_DESKTOP=0
    return
  fi

  if [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] || [[ "${DESKTOP_SESSION:-}" == *gnome* ]]; then
    GNOME_DESKTOP=1
    log "Detected GNOME desktop environment."
  else
    GNOME_DESKTOP=0
    log "GNOME desktop not detected; skipping desktop integration."
  fi
}

install_pkgs() {
  # usage: install_pkgs pkg1 pkg2 ...
  case "$PKG_MGR" in
    dnf)
      $SUDO dnf -y install "$@"
      ;;
    apt)
      if [[ "$APT_UPDATED" -eq 0 ]]; then
        log "Running apt-get update…"
        $SUDO apt-get update -y
        APT_UPDATED=1
      fi
      $SUDO apt-get install -y "$@"
      ;;
    brew)
      brew install "$@" || true  # brew is idempotent-ish
      ;;
    *)
      err "No package manager configured."
      exit 1
      ;;
  esac
}

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

# ----- detect OS / desktop -----
detect_os
detect_gnome

# ----- ensure cargo (and rustc) -----
if ! command -v cargo >/dev/null 2>&1; then
  if [[ "$OS" == "linux" ]]; then
    log "Installing Cargo (and Rust toolchain)…"
    install_pkgs cargo rustc || {
      err "Failed to install cargo/rustc."
      exit 1
    }
  else
    # macOS: use brew's Rust (includes cargo)
    log "Installing Rust (with cargo) via Homebrew…"
    install_pkgs rust || {
      err "Failed to install Rust/cargo via Homebrew."
      exit 1
    }
  fi
else
  log "Cargo already present: $(cargo --version 2>/dev/null || echo 'version unknown')"
fi

# Make sure ~/.cargo/bin is in PATH for this session
export PATH="$HOME/.cargo/bin:$PATH"

# ----- ensure curl -----
if ! command -v curl >/dev/null 2>&1; then
  log "Installing curl…"
  install_pkgs curl || {
    err "Failed to install curl."
    exit 1
  }
else
  log "curl already present."
fi

# ----- install yazi if missing (via cargo, crate: yazi-build) -----
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

# ----- link configs (works everywhere) -----
log "Linking Yazi configuration…"
mkdir -p "$HOME/.config/yazi/"
maybe_link "$PWD/yazi.toml" "$HOME/.config/yazi/yazi.toml"

mkdir -p "$HOME/.local/share/applications/"
maybe_link "$PWD/yazi.desktop" "$HOME/.local/share/applications/yazi.desktop"

# ----- GNOME-only desktop integration (ImageMagick, icon, gtk, desktop-db) -----
if [[ "$GNOME_DESKTOP" -eq 1 ]]; then
  log "Setting up GNOME desktop integration for Yazi…"

  # Ensure ImageMagick (magick) is present
  if ! command -v magick >/dev/null 2>&1; then
    log "Installing ImageMagick (for webp->png)…"
    case "$PKG_MGR" in
      dnf)
        install_pkgs ImageMagick || {
          err "Failed to install ImageMagick (dnf)."
          exit 1
        }
        ;;
      apt)
        install_pkgs imagemagick || {
          err "Failed to install ImageMagick (apt)."
          exit 1
        }
        ;;
      brew)
        # Normally GNOME + brew is unusual, but handle it anyway
        install_pkgs imagemagick || {
          err "Failed to install ImageMagick (brew)."
          exit 1
        }
        ;;
    esac
  else
    log "ImageMagick already present: $(magick -version | head -n1)"
  fi

  # desktop-file-utils for update-desktop-database (Linux-only)
  if [[ "$OS" == "linux" && "$PKG_MGR" != "brew" ]]; then
    if ! command -v update-desktop-database >/dev/null 2>&1; then
      log "Installing desktop-file-utils…"
      install_pkgs desktop-file-utils || true
    fi
  fi

  # Icon install
  log "Installing Yazi icon…"
  ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
  ICON_TMP="$(mktemp)"
  mkdir -p "$ICON_DIR"
  curl -fsSL "https://yazi-rs.github.io/webp/logo.webp" -o "$ICON_TMP"
  magick "$ICON_TMP" -resize 256x256 "$ICON_DIR/yazi.png"
  rm -f "$ICON_TMP"

  gtk-update-icon-cache "$HOME/.local/share/icons/hicolor" -f 2>/dev/null || true
  log "✅ Installed: $ICON_DIR/yazi.png (use Icon=yazi in your .desktop)"

  update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
else
  log "Skipping ImageMagick/gtk/desktop-db setup (not GNOME)."
fi

log "Done."

