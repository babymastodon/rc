#!/usr/bin/env bash
set -euo pipefail

log()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }
need_sudo() { if [[ $EUID -ne 0 ]]; then echo "sudo"; fi; }

WSF_REPO_URL="${WSF_REPO_URL:-https://github.com/daniel-g-carrasco/wayland-scroll-factor.git}"
WSF_VERSION="${WSF_VERSION:-v0.3.5}"
WSF_SOURCE_DIR="${WSF_SOURCE_DIR:-$HOME/.local/src/wayland-scroll-factor}"
WSF_PREFIX="${WSF_PREFIX:-$HOME/.local}"
WSF_BUILD_DIR="${WSF_BUILD_DIR:-$WSF_SOURCE_DIR/build}"
WSF_ENABLE="${WSF_ENABLE:-1}"
WSF_INSTALL_DEPS="${WSF_INSTALL_DEPS:-1}"

OS=""
PKG_MGR=""
SUDO=""
APT_UPDATED=0

have() {
  command -v "$1" >/dev/null 2>&1
}

usage() {
  cat <<EOF
Usage:
  $0              # install WSF ${WSF_VERSION} from source and run 'wsf enable'
  $0 --no-enable  # install WSF but skip preload enablement
  $0 --no-deps    # skip package-manager dependency installation

Environment overrides:
  WSF_VERSION=${WSF_VERSION}
  WSF_SOURCE_DIR=${WSF_SOURCE_DIR}
  WSF_PREFIX=${WSF_PREFIX}
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --enable)
        WSF_ENABLE=1
        shift
        ;;
      --no-enable)
        WSF_ENABLE=0
        shift
        ;;
      --no-deps)
        WSF_INSTALL_DEPS=0
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        err "Unknown argument: $1"
        usage >&2
        exit 1
        ;;
    esac
  done
}

detect_os() {
  case "${OSTYPE:-unknown}" in
    linux-gnu*|linux*)
      OS="linux"
      SUDO="$(need_sudo || true)"
      if have dnf; then
        PKG_MGR="dnf"
      elif have apt-get; then
        PKG_MGR="apt"
      elif have pacman; then
        PKG_MGR="pacman"
      elif have zypper; then
        PKG_MGR="zypper"
      else
        PKG_MGR="unknown"
      fi
      ;;
    *)
      err "WSF targets Linux Wayland desktops; unsupported OS: ${OSTYPE:-unknown}"
      exit 1
      ;;
  esac

  log "Detected OS: $OS (pkg manager: $PKG_MGR)"
}

install_pkgs() {
  case "$PKG_MGR" in
    dnf)
      $SUDO dnf -y install "$@"
      ;;
    apt)
      if [[ "$APT_UPDATED" -eq 0 ]]; then
        log "Running apt-get update..."
        $SUDO apt-get update -y
        APT_UPDATED=1
      fi
      $SUDO apt-get install -y "$@"
      ;;
    pacman)
      $SUDO pacman -S --needed --noconfirm "$@"
      ;;
    zypper)
      $SUDO zypper install -y "$@"
      ;;
    *)
      err "No supported package manager found. Install WSF build dependencies manually, then rerun with --no-deps."
      exit 1
      ;;
  esac
}

install_dnf_libinput_pkg() {
  if $SUDO dnf -y install libinput-utils; then
    return 0
  fi

  if $SUDO dnf -y install libinput-tools; then
    return 0
  fi

  warn "Could not install libinput diagnostics package (libinput-utils/libinput-tools)."
  warn "WSF can still run; 'wsf doctor' will show less diagnostics until it is installed."
}

install_deps() {
  if [[ "$WSF_INSTALL_DEPS" != "1" ]]; then
    log "Skipping package dependency installation."
    return
  fi

  case "$PKG_MGR" in
    dnf)
      log "Installing WSF build/runtime packages via dnf..."
      install_pkgs gcc gcc-c++ make meson ninja-build pkgconf-pkg-config git \
        python3 python3-gobject gtk4 libadwaita desktop-file-utils
      install_dnf_libinput_pkg
      ;;
    apt)
      log "Installing WSF build/runtime packages via apt..."
      install_pkgs build-essential meson ninja-build pkg-config git \
        python3 python3-gi gir1.2-adw-1 libgtk-4-1 libadwaita-1-0 \
        libinput-tools desktop-file-utils
      ;;
    pacman)
      log "Installing WSF build/runtime packages via pacman..."
      install_pkgs base-devel meson ninja pkgconf git \
        python python-gobject gtk4 libadwaita libinput-tools desktop-file-utils
      ;;
    zypper)
      log "Installing WSF build/runtime packages via zypper..."
      install_pkgs gcc gcc-c++ make meson ninja pkg-config git \
        python3 python3-gobject gtk4 libadwaita-1-0 libinput-tools desktop-file-utils
      ;;
    *)
      err "No supported package manager found. Install WSF build dependencies manually, then rerun with --no-deps."
      exit 1
      ;;
  esac
}

require_build_tools() {
  local missing=() tool
  for tool in git meson ninja; do
    if ! have "$tool"; then
      missing+=("$tool")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    err "Missing required build tool(s): ${missing[*]}"
    printf 'Run this script without --no-deps, or install the missing tools manually.\n' >&2
    exit 1
  fi
}

checkout_source() {
  if [[ -d "$WSF_SOURCE_DIR/.git" ]]; then
    log "Updating WSF source in $WSF_SOURCE_DIR..."
    git -C "$WSF_SOURCE_DIR" remote set-url origin "$WSF_REPO_URL"
    git -C "$WSF_SOURCE_DIR" fetch --tags --force origin
    git -C "$WSF_SOURCE_DIR" checkout --detach "$WSF_VERSION"
  elif [[ -e "$WSF_SOURCE_DIR" ]]; then
    err "Source path exists but is not a Git checkout: $WSF_SOURCE_DIR"
    exit 1
  else
    log "Cloning WSF ${WSF_VERSION} into $WSF_SOURCE_DIR..."
    mkdir -p "$(dirname "$WSF_SOURCE_DIR")"
    git clone --depth 1 --branch "$WSF_VERSION" "$WSF_REPO_URL" "$WSF_SOURCE_DIR"
  fi
}

build_and_install() {
  log "Building WSF ${WSF_VERSION}..."
  if [[ ! -f "$WSF_BUILD_DIR/build.ninja" ]]; then
    meson setup "$WSF_BUILD_DIR" "$WSF_SOURCE_DIR" --prefix="$WSF_PREFIX" --buildtype=release
  else
    meson setup --reconfigure "$WSF_BUILD_DIR" "$WSF_SOURCE_DIR" --prefix="$WSF_PREFIX" --buildtype=release
  fi

  meson compile -C "$WSF_BUILD_DIR"
  meson install -C "$WSF_BUILD_DIR"

  if have update-desktop-database; then
    update-desktop-database "$WSF_PREFIX/share/applications" >/dev/null 2>&1 || true
  fi

  if have gtk-update-icon-cache; then
    gtk-update-icon-cache -q "$WSF_PREFIX/share/icons/hicolor" >/dev/null 2>&1 || true
  fi
}

wsf_bin() {
  if [[ -x "$WSF_PREFIX/bin/wsf" ]]; then
    printf '%s\n' "$WSF_PREFIX/bin/wsf"
  elif have wsf; then
    command -v wsf
  else
    return 1
  fi
}

finish_setup() {
  local bin

  export PATH="$WSF_PREFIX/bin:$HOME/.local/bin:$PATH"

  if bin="$(wsf_bin)"; then
    log "WSF installed: $("$bin" --version 2>/dev/null | head -n1 || echo "$bin")"
  else
    warn "Install finished, but 'wsf' was not found on PATH. Expected: $WSF_PREFIX/bin/wsf"
    return
  fi

  if [[ "$WSF_ENABLE" == "1" ]]; then
    log "Enabling WSF preload for the current user..."
    "$bin" enable
    warn "Log out and back in for the WSF preload to activate in GNOME Shell."
  else
    warn "Skipped WSF preload enablement. Run '$bin enable' later if needed."
  fi
}

main() {
  parse_args "$@"
  detect_os
  install_deps
  require_build_tools
  checkout_source
  build_and_install
  finish_setup

  log "Done."
}

main "$@"
