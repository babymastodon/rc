#!/usr/bin/env bash

set -euo pipefail

echo "=== Setting up runtimes, CLI tools, and CoC language servers with mise ==="

OS="$(uname -s)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MISE_CONFIG_PATH="${SCRIPT_DIR}/config.toml"
GLOBAL_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mise"
GLOBAL_CONFIG_PATH="${GLOBAL_CONFIG_DIR}/config.toml"

if [[ "$OS" == "Darwin" ]] && ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Install Homebrew first: https://brew.sh/" >&2
  exit 1
fi

detect_pm() {
  if [[ "$OS" == "Darwin" ]]; then
    echo "brew"
  elif command -v apt >/dev/null 2>&1; then
    echo "apt"
  elif command -v pacman >/dev/null 2>&1; then
    echo "pacman"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v yum >/dev/null 2>&1; then
    echo "yum"
  else
    echo ""
  fi
}

PM="$(detect_pm)"

if [[ -z "$PM" ]]; then
  echo "No supported package manager detected (apt/pacman/dnf/yum/brew)." >&2
  echo "Install curl and clang tooling manually, then rerun this script." >&2
  exit 1
fi

echo "Detected OS: $OS"
echo "Using package manager: $PM"
echo

export PATH="${HOME}/.local/bin:$PATH"

install_pkg() {
  case "$PM" in
    apt)
      sudo apt update
      sudo apt install -y "$@"
      ;;
    pacman)
      sudo pacman -Sy --noconfirm "$@"
      ;;
    dnf)
      sudo dnf install -y "$@"
      ;;
    yum)
      sudo yum install -y "$@"
      ;;
    brew)
      brew install "$@"
      ;;
  esac
}

ensure_mise() {
  if command -v mise >/dev/null 2>&1; then
    return 0
  fi

  if [[ -x "${HOME}/.local/bin/mise" ]]; then
    export PATH="${HOME}/.local/bin:$PATH"
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    install_pkg curl
  fi

  echo "Installing mise..."
  curl -fsSL https://mise.run | MISE_INSTALL_HELP=0 sh
  export PATH="${HOME}/.local/bin:$PATH"

  if ! command -v mise >/dev/null 2>&1; then
    echo "mise install completed, but mise is still not on PATH." >&2
    exit 1
  fi
}

remove_legacy_mise_bashrc_hook() {
  local bashrc="${HOME}/.bashrc"
  local activate_hook_re='^[[:space:]]*eval[[:space:]]+"\$\([^)]*mise"?[[:space:]]+activate[[:space:]]+((-q|--quiet)[[:space:]]+)?bash\)"[[:space:]]*$'
  local tmp

  [[ -f "$bashrc" ]] || return 0

  if grep -qxF '# >>> mise >>>' "$bashrc" && grep -qxF '# <<< mise <<<' "$bashrc"; then
    tmp="${bashrc}.tmp.$$"
    awk '
      $0 == "# >>> mise >>>" { skip = 1; next }
      $0 == "# <<< mise <<<" { skip = 0; next }
      !skip { print }
    ' "$bashrc" > "$tmp"
    mv "$tmp" "$bashrc"
    echo "Removed legacy mise activation block from ${bashrc}."
  fi

  if grep -Eq "$activate_hook_re" "$bashrc"; then
    tmp="${bashrc}.tmp.$$"
    grep -Ev "$activate_hook_re" "$bashrc" > "$tmp" || true
    mv "$tmp" "$bashrc"
    echo "Removed legacy mise activate hook from ${bashrc}."
  fi
}

activate_mise() {
  eval "$(mise env -s bash)"
  hash -r
}

configure_global_tooling() {
  # Make this repo's config.toml the global mise config by symlinking it into
  # mise's default global config location, then let mise install from it
  # directly. We deliberately do NOT reparse the TOML into `mise use -g` specs:
  # mise does not accept tool options (e.g. aws-cli's symlink_bins) via the
  # inline `tool@version[opts]` CLI form, so flattening tables that way feeds the
  # option into the version string and breaks resolution. Reading config.toml is
  # what mise is for.
  echo "Linking ${MISE_CONFIG_PATH} as the global mise config (${GLOBAL_CONFIG_PATH})..."
  mkdir -p "$GLOBAL_CONFIG_DIR"

  if [[ -L "$GLOBAL_CONFIG_PATH" && "$(readlink "$GLOBAL_CONFIG_PATH")" == "$MISE_CONFIG_PATH" ]]; then
    : # already linked correctly
  else
    if [[ -e "$GLOBAL_CONFIG_PATH" || -L "$GLOBAL_CONFIG_PATH" ]]; then
      echo "  Existing ${GLOBAL_CONFIG_PATH} found; backing it up to ${GLOBAL_CONFIG_PATH}.bak"
      mv -f "$GLOBAL_CONFIG_PATH" "${GLOBAL_CONFIG_PATH}.bak"
    fi
    ln -s "$MISE_CONFIG_PATH" "$GLOBAL_CONFIG_PATH"
  fi

  mise trust "$GLOBAL_CONFIG_PATH" >/dev/null

  # Install one tool at a time: parallel installs race on the gpg keyboxd
  # database on a cold keyring ("SQL library used incorrectly"), which breaks
  # node's signature check and cascades to every npm tool that depends on node.
  echo "Installing tools from ${GLOBAL_CONFIG_PATH}..."
  MISE_JOBS=1 mise install
}

ensure_clang_tooling() {
  case "$PM" in
    apt)
      command -v clang >/dev/null 2>&1 || install_pkg clang
      command -v clangd >/dev/null 2>&1 || install_pkg clangd || true
      ;;
    pacman)
      command -v clang >/dev/null 2>&1 || install_pkg clang
      command -v clangd >/dev/null 2>&1 || install_pkg clang
      ;;
    dnf|yum)
      command -v clang >/dev/null 2>&1 || install_pkg clang
      command -v clangd >/dev/null 2>&1 || install_pkg clang-tools-extra || install_pkg clangd || true
      ;;
    brew)
      if ! command -v clang >/dev/null 2>&1 || ! command -v clangd >/dev/null 2>&1; then
        install_pkg llvm
        echo 'Note: on macOS with llvm via brew, you may need:'
        echo '  export PATH="$(brew --prefix llvm)/bin:$PATH"'
      fi
      ;;
  esac
}

ensure_mise
remove_legacy_mise_bashrc_hook
configure_global_tooling
activate_mise
ensure_clang_tooling

#############################
# Language servers / tools
#############################

if ! command -v clangd >/dev/null 2>&1; then
  echo
  echo "clangd still not found; you may need to install it manually for C/C++ support."
fi

printf '\n'
printf 'Run `source ~/.bashrc` before proceeding.\n'
printf '\n'
