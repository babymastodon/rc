#!/usr/bin/env bash
set -euo pipefail

log()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

HERDR_VERSION="${HERDR_VERSION:-v0.5.9}"
HERDR_DOWNLOAD_ROOT="https://github.com/ogulcancelik/herdr/releases/download"

have() {
  command -v "$1" >/dev/null 2>&1
}

print_shell_setup_guidance() {
  printf 'Run `./install.sh` from the repo root, then `source ~/.bashrc`, then rerun this script.\n' >&2
}

detect_os() {
  case "${OSTYPE:-unknown}" in
    darwin*)
      printf 'macos\n'
      ;;
    linux-gnu*|linux*)
      printf 'linux\n'
      ;;
    *)
      err "Unsupported OS: ${OSTYPE:-unknown}"
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
      printf 'aarch64\n'
      ;;
    *)
      err "Unsupported architecture: $(uname -m)"
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
    err "Need curl or wget to download herdr."
    exit 1
  fi
}

sha256_file() {
  local file="$1"

  if have sha256sum; then
    sha256sum "$file" | awk '{print $1}'
  elif have shasum; then
    shasum -a 256 "$file" | awk '{print $1}'
  elif have openssl; then
    openssl dgst -sha256 "$file" | awk '{print $NF}'
  else
    err "Need sha256sum, shasum, or openssl to verify herdr."
    exit 1
  fi
}

get_expected_sha256() {
  local os="$1" arch="$2"

  case "${os}-${arch}" in
    linux-x86_64)
      printf '13fec1d1caa82fa3925416d734976c93c7a84d5a87126af319090a38179de76e\n'
      ;;
    linux-aarch64)
      printf '9a38941a4a54d77e0c5101d181270ca95f12e5045e31592f00f007630023810d\n'
      ;;
    macos-aarch64)
      printf '8b796f3717862aae81daae5b9d6c1f1929d758aacea0b4433bbf5300ed2ca6ac\n'
      ;;
    macos-x86_64)
      printf '00e6c346dcc48c1cebfb313c7f120a1f60426af8a41860837210c82f6657bcb0\n'
      ;;
    *)
      err "No pinned herdr release asset for ${os}-${arch}"
      exit 1
      ;;
  esac
}

install_binary() {
  local os="$1" arch="$2" asset url expected_sha actual_sha tmpdir tmpfile target

  asset="herdr-${os}-${arch}"
  url="${HERDR_DOWNLOAD_ROOT}/${HERDR_VERSION}/${asset}"
  expected_sha="$(get_expected_sha256 "$os" "$arch")"
  tmpdir="$(mktemp -d)"
  tmpfile="${tmpdir}/herdr"
  target="$HOME/.local/bin/herdr"

  trap "rm -rf -- '$tmpdir'" EXIT

  log "Downloading herdr ${HERDR_VERSION} (${asset}) from GitHub..."
  download_file "$url" "$tmpfile"

  actual_sha="$(sha256_file "$tmpfile")"
  if [[ "$actual_sha" != "$expected_sha" ]]; then
    err "SHA256 mismatch for ${asset}: expected ${expected_sha}, got ${actual_sha}"
    exit 1
  fi

  mkdir -p "$HOME/.local/bin"
  chmod +x "$tmpfile"
  mv "$tmpfile" "$target"
  log "Installed herdr to ${target}"

  rm -rf -- "$tmpdir"
  trap - EXIT
}

main() {
  local os arch

  if ! have curl && ! have wget; then
    err "curl or wget is required to install herdr."
    print_shell_setup_guidance
    exit 1
  fi

  export PATH="$HOME/.local/bin:$PATH"
  os="$(detect_os)"
  arch="$(detect_arch)"

  if have herdr; then
    log "Existing herdr detected: $(herdr --version 2>/dev/null | head -n1 || echo 'version lookup skipped')"
    warn "Reinstalling pinned herdr ${HERDR_VERSION} to keep this repo deterministic."
  else
    log "Installing herdr ${HERDR_VERSION} for ${os}-${arch}..."
  fi

  install_binary "$os" "$arch"

  if have herdr; then
    log "herdr installed: $(herdr --version 2>/dev/null | head -n1 || echo 'version lookup skipped')"
  else
    warn "Install finished, but \`herdr\` is not on PATH in this shell yet."
  fi

  printf '\n'
  printf 'Next step: run `hoo` to attach to the named herdr session.\n'
}

main "$@"
