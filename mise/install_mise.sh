#!/usr/bin/env bash

set -euo pipefail

echo "=== Setting up runtimes + CoC language servers with mise ==="

OS="$(uname -s)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MISE_CONFIG_PATH="${SCRIPT_DIR}/config.toml"

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
  curl https://mise.run | sh
  export PATH="${HOME}/.local/bin:$PATH"

  if ! command -v mise >/dev/null 2>&1; then
    echo "mise install completed, but mise is still not on PATH." >&2
    exit 1
  fi
}

activate_mise() {
  eval "$(mise env -s bash)"
  hash -r
}

configure_global_tooling() {
  local in_tools=0 line key value
  local -a tool_specs=()

  echo "Applying global mise defaults from ${MISE_CONFIG_PATH}..."

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    [[ -z "$line" || "$line" == \#* ]] && continue

    if [[ "$line" =~ ^\[(.*)\]$ ]]; then
      if [[ "${BASH_REMATCH[1]}" == "tools" ]]; then
        in_tools=1
      else
        in_tools=0
      fi
      continue
    fi

    (( in_tools )) || continue

    if [[ "$line" =~ ^\"([^\"]+)\"[[:space:]]*=[[:space:]]*\"([^\"]+)\"$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      tool_specs+=("${key}@${value}")
      continue
    fi

    if [[ "$line" =~ ^([A-Za-z0-9_.-]+)[[:space:]]*=[[:space:]]*\"([^\"]+)\"$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      tool_specs+=("${key}@${value}")
      continue
    fi

    echo "Unsupported mise config line in ${MISE_CONFIG_PATH}: ${line}" >&2
    exit 1
  done < "$MISE_CONFIG_PATH"

  if (( ${#tool_specs[@]} == 0 )); then
    echo "No tools found in ${MISE_CONFIG_PATH}." >&2
    exit 1
  fi

  echo "  mise use -g ${tool_specs[*]}"
  mise use -g "${tool_specs[@]}"
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
