#!/usr/bin/env bash
set -euo pipefail

log()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }
need_sudo() { if [[ ${EUID:-$(id -u)} -ne 0 ]]; then echo "sudo"; fi; }

SUDO="$(need_sudo || true)"
MIN_VERSION="3.6"
FALLBACK_VERSION="3.6a"
LINUX_INSTALL_ROOT="${HOME}/.local/share/tmux-builds"
LINUX_BIN_DIR="${HOME}/.local/bin"

have() {
  command -v "$1" >/dev/null 2>&1
}

version_ge() {
  local left="$1" right="$2"
  [[ "$(printf '%s\n%s\n' "$right" "$left" | sort -V | tail -n1)" == "$left" ]]
}

normalize_version() {
  local raw="$1"
  raw="${raw##*:}"
  raw="${raw%%-*}"
  printf '%s\n' "$raw"
}

get_installed_tmux_version() {
  local raw=""
  raw="$(tmux -V 2>/dev/null | awk '{print $2; exit}' || true)"
  if [[ -n "$raw" ]]; then
    normalize_version "$raw"
  fi
}

detect_linux_pm() {
  if have apt-get; then
    printf 'apt\n'
  elif have dnf; then
    printf 'dnf\n'
  elif have yum; then
    printf 'yum\n'
  elif have pacman; then
    printf 'pacman\n'
  elif have zypper; then
    printf 'zypper\n'
  else
    printf '\n'
  fi
}

get_repo_tmux_version() {
  local pm="$1" raw=""

  case "$pm" in
    apt)
      raw="$(apt-cache policy tmux 2>/dev/null | awk '/Candidate:/ {print $2; exit}')"
      ;;
    dnf)
      raw="$(dnf info tmux 2>/dev/null | awk '$1 == "Version" && $2 == ":" {print $3; exit}')"
      ;;
    yum)
      raw="$(yum info tmux 2>/dev/null | awk '$1 == "Version" && $2 == ":" {print $3; exit}')"
      ;;
    pacman)
      raw="$(pacman -Si tmux 2>/dev/null | awk '/^Version/ {print $3; exit}')"
      ;;
    zypper)
      raw="$(zypper info tmux 2>/dev/null | awk -F': ' '/^Version/ {print $2; exit}')"
      ;;
  esac

  if [[ -n "$raw" && "$raw" != "(none)" ]]; then
    normalize_version "$raw"
  fi
}

install_tmux_from_pm() {
  local pm="$1"

  case "$pm" in
    apt)
      $SUDO apt-get update -y
      $SUDO apt-get install -y tmux
      ;;
    dnf)
      $SUDO dnf install -y tmux
      ;;
    yum)
      $SUDO yum install -y tmux
      ;;
    pacman)
      $SUDO pacman -Sy --noconfirm tmux
      ;;
    zypper)
      $SUDO zypper --non-interactive refresh
      $SUDO zypper --non-interactive install -y tmux
      ;;
    *)
      err "Unsupported package manager: $pm"
      exit 1
      ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64)
      printf 'x86_64\n'
      ;;
    arm64|aarch64)
      printf 'arm64\n'
      ;;
    *)
      err "Unsupported Linux architecture: $(uname -m)"
      exit 1
      ;;
  esac
}

download_file() {
  local url="$1" dest="$2"

  if have curl; then
    curl -fsSL "$url" -o "$dest"
  elif have wget; then
    wget -O "$dest" "$url"
  else
    err "Need curl or wget to download tmux fallback tarball."
    exit 1
  fi
}

verify_sha256() {
  local file="$1" expected="$2" actual=""

  if have sha256sum; then
    actual="$(sha256sum "$file" | awk '{print $1}')"
  elif have shasum; then
    actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  elif have openssl; then
    actual="$(openssl dgst -sha256 "$file" | awk '{print $NF}')"
  else
    err "Need sha256sum, shasum, or openssl to verify tmux download."
    exit 1
  fi

  if [[ "$actual" != "$expected" ]]; then
    err "SHA256 mismatch for $(basename "$file"): expected $expected, got $actual"
    exit 1
  fi
}

install_tmux_from_tarball() {
  local arch url sha256 tmpdir archive install_dir extracted_dir

  arch="$(detect_arch)"
  case "$arch" in
    arm64)
      url="https://github.com/tmux/tmux-builds/releases/download/v3.6a/tmux-3.6a-linux-arm64.tar.gz"
      sha256="bb5afd9d646df54a7d7c66e198aa22c7d293c7453534f1670f7c540534db8b5e"
      ;;
    x86_64)
      url="https://github.com/tmux/tmux-builds/releases/download/v3.6a/tmux-3.6a-linux-x86_64.tar.gz"
      sha256="c0a772a5e6ca8f129b0111d10029a52e02bcbc8352d5a8c0d3de8466a1e59c2e"
      ;;
  esac

  tmpdir="$(mktemp -d)"
  archive="${tmpdir}/tmux-${FALLBACK_VERSION}-${arch}.tar.gz"
  install_dir="${LINUX_INSTALL_ROOT}/tmux-${FALLBACK_VERSION}-${arch}"

  trap 'rm -rf "$tmpdir"' EXIT

  log "Downloading tmux ${FALLBACK_VERSION} for ${arch} from GitHub..."
  download_file "$url" "$archive"

  log "Verifying tmux download checksum..."
  verify_sha256 "$archive" "$sha256"

  mkdir -p "$LINUX_INSTALL_ROOT" "$LINUX_BIN_DIR"
  rm -rf "$install_dir"
  mkdir -p "$install_dir"

  tar -xzf "$archive" -C "$install_dir"
  extracted_dir="$(find "$install_dir" -mindepth 1 -maxdepth 1 -type d | head -n1 || true)"
  if [[ -n "$extracted_dir" && -x "$extracted_dir/tmux" ]]; then
    ln -sfn "$extracted_dir/tmux" "${LINUX_BIN_DIR}/tmux"
  elif [[ -x "$install_dir/tmux" ]]; then
    ln -sfn "$install_dir/tmux" "${LINUX_BIN_DIR}/tmux"
  else
    err "Extracted tmux binary not found in ${install_dir}"
    exit 1
  fi

  if [[ ":${PATH}:" != *":${LINUX_BIN_DIR}:"* ]]; then
    warn "${LINUX_BIN_DIR} is not on PATH in this shell."
  fi

  log "Installed tmux ${FALLBACK_VERSION} into ${LINUX_BIN_DIR}/tmux"
}

install_macos() {
  local installed_version

  if have tmux; then
    installed_version="$(get_installed_tmux_version)"
    if [[ -n "$installed_version" ]] && version_ge "$installed_version" "$MIN_VERSION"; then
      log "tmux already installed: $(tmux -V 2>/dev/null || echo "tmux ${installed_version}")"
      return
    fi

    warn "Existing tmux version ${installed_version:-unknown} is older than ${MIN_VERSION}; upgrading with Homebrew."
  fi

  if ! have brew; then
    err "Homebrew not found. Install Homebrew first: https://brew.sh/"
    exit 1
  fi

  log "Installing tmux with Homebrew..."
  brew install tmux
}

install_linux() {
  local pm repo_version installed_version

  if have tmux; then
    installed_version="$(get_installed_tmux_version)"
    if [[ -n "$installed_version" ]] && version_ge "$installed_version" "$MIN_VERSION"; then
      log "tmux already installed: $(tmux -V 2>/dev/null || echo "tmux ${installed_version}")"
      return
    fi

    warn "Existing tmux version ${installed_version:-unknown} is older than ${MIN_VERSION}; upgrading."
  fi

  pm="$(detect_linux_pm)"
  if [[ -z "$pm" ]]; then
    warn "No supported Linux package manager detected; using GitHub fallback."
    install_tmux_from_tarball
    return
  fi

  log "Detected Linux package manager: $pm"
  repo_version="$(get_repo_tmux_version "$pm" || true)"

  if [[ -n "$repo_version" ]]; then
    log "Package manager offers tmux ${repo_version}"
    if version_ge "$repo_version" "$MIN_VERSION"; then
      log "Installing tmux from ${pm} because ${repo_version} >= ${MIN_VERSION}"
      install_tmux_from_pm "$pm"
      return
    fi

    warn "Package manager tmux version ${repo_version} is older than ${MIN_VERSION}; using GitHub fallback."
  else
    warn "Could not determine tmux version from ${pm}; using GitHub fallback."
  fi

  install_tmux_from_tarball
}

main() {
  case "$(uname -s)" in
    Darwin)
      install_macos
      ;;
    Linux)
      install_linux
      ;;
    *)
      err "Unsupported OS: $(uname -s)"
      exit 1
      ;;
  esac

  if have tmux; then
    log "tmux installed: $(tmux -V 2>/dev/null || echo 'version lookup skipped')"
  fi
}

main "$@"
