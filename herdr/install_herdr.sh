#!/usr/bin/env bash
set -euo pipefail

log()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HERDR_REPO_URL="${HERDR_REPO_URL:-https://github.com/babymastodon/herdr.git}"
HERDR_BRANCH="${HERDR_BRANCH:-double-click-word-select}"
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

clone_source() {
  local dest="$1"

  log "Cloning herdr from ${HERDR_SOURCE_URL}..."
  git clone --depth 1 --branch "$HERDR_BRANCH" "$HERDR_REPO_URL" "$dest"
}

install_binary() {
  local source_dir="$1" built_binary="$1/target/release/herdr" target="$HOME/.local/bin/herdr"

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
  mise exec -C "$source_dir" -- cargo build --release --locked

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
