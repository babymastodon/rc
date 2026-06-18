#!/usr/bin/env bash
set -euo pipefail

log()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HERDR_REPO_URL="${HERDR_REPO_URL:-https://github.com/babymastodon/herdr.git}"
HERDR_BRANCH="${HERDR_BRANCH:-selection-darkgrey-rebased}"
HERDR_SOURCE_URL="${HERDR_SOURCE_URL:-https://github.com/babymastodon/herdr/tree/$HERDR_BRANCH}"
HERDR_MISE_CONFIG="${HERDR_MISE_CONFIG:-$SCRIPT_DIR/mise.toml}"
HERDR_CONFIG_SRC="${HERDR_CONFIG_SRC:-$SCRIPT_DIR/config.toml}"
HERDR_CONFIG_DST="${HERDR_CONFIG_DST:-$HOME/.config/herdr/config.toml}"

have() {
  command -v "$1" >/dev/null 2>&1
}

print_shell_setup_guidance() {
  printf 'Run `./install.sh` from the repo root, then `source ~/.bashrc`, then rerun this script.\n' >&2
}

require_tool() {
  if ! have "$1"; then
    err "Missing required tool: $1"
    print_shell_setup_guidance
    exit 1
  fi
}

macos_developer_dir_for_herdr_build() {
  local developer_dir

  if [[ "$(uname -s)" != "Darwin" ]]; then
    return
  fi

  if [[ -d /Library/Developer/CommandLineTools ]]; then
    printf '%s\n' /Library/Developer/CommandLineTools
    return
  fi

  developer_dir="$(xcode-select -p 2>/dev/null || true)"
  if [[ -n "$developer_dir" && -d "$developer_dir" ]]; then
    printf '%s\n' "$developer_dir"
    return
  fi

  err "No usable macOS developer directory found."
  printf 'Install Command Line Tools with `xcode-select --install`, then rerun this script.\n' >&2
  exit 1
}

zig_for_herdr_build() {
  local candidate version

  if [[ -n "${ZIG:-}" ]]; then
    printf '%s\n' "$ZIG"
    return
  fi

  if [[ "$(uname -s)" != "Darwin" ]]; then
    return
  fi

  # Homebrew's zig@0.15 includes a backported Darwin linker fix needed by
  # Xcode/CommandLineTools 26 SDKs, while the upstream 0.15.2 tarball does not.
  for candidate in /opt/homebrew/opt/zig@0.15/bin/zig /usr/local/opt/zig@0.15/bin/zig; do
    if [[ ! -x "$candidate" ]]; then
      continue
    fi

    version="$("$candidate" version 2>/dev/null || true)"
    if [[ "$version" == "0.15.2" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done
}

clone_source() {
  local dest="$1"

  log "Cloning herdr from ${HERDR_SOURCE_URL}..."
  git clone --depth 1 --branch "$HERDR_BRANCH" "$HERDR_REPO_URL" "$dest"
}

patch_source() {
  local source_dir="$1" build_rs="$1/build.rs"

  if [[ ! -f "$build_rs" ]]; then
    err "Expected build script not found: ${build_rs}"
    exit 1
  fi

  if grep -q -- '-Demit-xcframework=false' "$build_rs"; then
    return
  fi

  log "Disabling unused Ghostty VT xcframework artifact for herdr build..."
  perl -0pi -e 's/(\n\s*\.arg\("-Demit-lib-vt"\))/$1\n        .arg("-Demit-xcframework=false")/' "$build_rs"

  if ! grep -q -- '-Demit-xcframework=false' "$build_rs"; then
    err "Failed to patch ${build_rs}"
    exit 1
  fi
}

install_binary() {
  local source_dir="$1" built_binary="$1/target/release/herdr" target="$HOME/.local/bin/herdr" developer_dir zig

  if [[ -f "$HERDR_MISE_CONFIG" ]]; then
    cp "$HERDR_MISE_CONFIG" "$source_dir/mise.toml"
  else
    warn "No mise config found at ${HERDR_MISE_CONFIG}; using the source checkout as-is."
  fi

  if [[ -f "$source_dir/mise.toml" ]]; then
    mise trust -q -y "$source_dir/mise.toml"
    mise install -y -C "$source_dir"
  fi

  log "Building herdr from source..."
  developer_dir="$(macos_developer_dir_for_herdr_build)"
  zig="$(zig_for_herdr_build)"
  if [[ -n "$zig" ]]; then
    log "Using Zig for herdr build: ${zig}"
    export ZIG="$zig"
  fi

  if [[ -n "$developer_dir" ]]; then
    DEVELOPER_DIR="$developer_dir" mise exec -C "$source_dir" -- cargo build --release --locked
  else
    mise exec -C "$source_dir" -- cargo build --release --locked
  fi

  if [[ ! -x "$built_binary" ]]; then
    err "Build finished, but no executable was found at ${built_binary}"
    exit 1
  fi

  mkdir -p "$HOME/.local/bin"
  install -m 0755 "$built_binary" "$target"
  log "Installed herdr to ${target}"
}

link_config() {
  local backup

  if [[ ! -f "$HERDR_CONFIG_SRC" ]]; then
    warn "Config source not found at ${HERDR_CONFIG_SRC}; skipping config link."
    return
  fi

  mkdir -p "$(dirname "$HERDR_CONFIG_DST")"

  if [[ -L "$HERDR_CONFIG_DST" ]]; then
    if [[ "$(readlink "$HERDR_CONFIG_DST")" == "$HERDR_CONFIG_SRC" ]]; then
      log "Config link already correct: ${HERDR_CONFIG_DST} -> ${HERDR_CONFIG_SRC}"
      return
    fi

    warn "Replacing existing config symlink at ${HERDR_CONFIG_DST}."
    rm -f "$HERDR_CONFIG_DST"
  elif [[ -e "$HERDR_CONFIG_DST" ]]; then
    backup="${HERDR_CONFIG_DST}.bak.$(date +%Y%m%d%H%M%S)"
    mv "$HERDR_CONFIG_DST" "$backup"
    log "Backed up existing config: ${backup}"
  fi

  ln -s "$HERDR_CONFIG_SRC" "$HERDR_CONFIG_DST"
  log "Linked config: ${HERDR_CONFIG_DST} -> ${HERDR_CONFIG_SRC}"
}

main() {
  local tmpdir source_dir

  export PATH="$HOME/.local/bin:$PATH"
  require_tool git
  require_tool mise
  require_tool cargo
  require_tool perl

  if have herdr; then
    log "Existing herdr detected: $(herdr --version 2>/dev/null | head -n1 || echo 'version lookup skipped')"
    warn "Reinstalling from ${HERDR_REPO_URL} (${HERDR_BRANCH})."
  else
    log "Installing herdr from ${HERDR_REPO_URL} (${HERDR_BRANCH})..."
  fi

  tmpdir="$(mktemp -d)"
  trap "rm -rf -- '$tmpdir'" EXIT
  source_dir="$tmpdir/herdr"

  clone_source "$source_dir"
  patch_source "$source_dir"
  install_binary "$source_dir"
  link_config

  rm -rf -- "$tmpdir"
  trap - EXIT

  if have herdr; then
    log "herdr installed: $(herdr --version 2>/dev/null | head -n1 || echo 'version lookup skipped')"
  else
    warn "Install finished, but \`herdr\` is not on PATH in this shell yet."
  fi

  printf '\n'
  printf 'Next step: run `hoo` to attach to the default herdr session.\n'
}

main "$@"
