#!/usr/bin/env bash

set -euo pipefail

echo "=== Setting up runtimes + CoC language servers with mise ==="

OS="$(uname -s)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MISE_CONFIG_PATH="${SCRIPT_DIR}/config.toml"
MISE_GLOBAL_CONFIG_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/mise/config.toml"
MISE_BIN="${HOME}/.local/bin/mise"

if [[ "$OS" == "Darwin" ]] && ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Install Homebrew first: https://brew.sh/" >&2
  exit 1
fi

print_shell_setup_guidance() {
  echo "Run \`${SCRIPT_DIR}/../install.sh\`, then \`source ~/.bashrc\`, then rerun this script." >&2
}

require_env_vars() {
  local missing=() var
  for var in "$@"; do
    if [[ -z "${!var:-}" ]]; then
      missing+=("$var")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    echo "Missing required environment variable(s): ${missing[*]}" >&2
    print_shell_setup_guidance
    exit 1
  fi
}

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

require_env_vars GOPATH GOBIN NPM_CONFIG_PREFIX
export PATH="${HOME}/.local/bin:${GOBIN}:$PATH"

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

  if [[ -x "$MISE_BIN" ]]; then
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
  export PATH="${GOBIN}:${NPM_CONFIG_PREFIX}/bin:$PATH"
  hash -r
}

clear_legacy_runtime_env() {
  unset GOROOT
  unset NODEJS_HOME
}

configure_global_tooling() {
  local in_tools=0 line key value

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

    if [[ "$line" =~ ^([A-Za-z0-9_.-]+)[[:space:]]*=[[:space:]]*\"([^\"]+)\"$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      echo "  mise use -g ${key}@${value}"
      mise use -g "${key}@${value}"
      continue
    fi

    echo "Unsupported mise config line in ${MISE_CONFIG_PATH}: ${line}" >&2
    exit 1
  done < "$MISE_CONFIG_PATH"
}

install_repo_tooling() {
  echo "Installing global runtime versions from ${MISE_GLOBAL_CONFIG_PATH}..."
  mise install
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
clear_legacy_runtime_env
configure_global_tooling
activate_mise
install_repo_tooling
activate_mise
hash -r
ensure_clang_tooling

echo
echo "Core runtimes done."
echo
echo "Make sure these bins are on PATH:"
echo "  mise:  \$HOME/.local/bin (plus mise activation in your shell)"
echo "  Go:    \$GOBIN"
echo "  npm:   \$NPM_CONFIG_PREFIX/bin"
echo

#############################
# Language servers / tools
#############################

export PATH="${NPM_CONFIG_PREFIX}/bin:${GOBIN}:$PATH"
export GOPATH GOBIN NPM_CONFIG_PREFIX
npm config set prefix "${NPM_CONFIG_PREFIX}"

echo ">>> Installing Pyright for coc-pyright"
if command -v npm >/dev/null 2>&1; then
  npm install -g pyright
else
  echo "npm not found; Pyright not installed."
fi
echo

echo ">>> Installing rust-analyzer for coc-rust-analyzer"
if command -v rust-analyzer >/dev/null 2>&1; then
  echo "rust-analyzer already installed."
else
  if command -v cargo >/dev/null 2>&1; then
    if cargo install --root "${HOME}/.local" rust-analyzer; then
      echo "rust-analyzer installed via cargo."
    else
      echo "cargo install rust-analyzer failed; install it manually from GitHub."
    fi
  else
    echo "cargo not found; rust-analyzer not installed."
  fi
fi
echo

echo ">>> Installing gopls for coc-go"
if command -v go >/dev/null 2>&1; then
  if go install golang.org/x/tools/gopls@latest; then
    echo "gopls installed via go install."
  else
    echo "go install gopls failed."
  fi
else
  echo "Go not found; gopls not installed."
fi
echo

echo ">>> Checking clangd for coc-clangd"
if command -v clangd >/dev/null 2>&1; then
  echo "clangd is installed."
else
  echo "clangd still not found; you may need to install it manually for C/C++ support."
fi
echo

echo ">>> Installing TypeScript + typescript-language-server for coc-tsserver"
if command -v npm >/dev/null 2>&1; then
  npm install -g typescript typescript-language-server
else
  echo "npm not found; tsserver LSP not installed."
fi
echo

echo ">>> Installing yaml-language-server for coc-yaml"
if command -v npm >/dev/null 2>&1; then
  npm install -g yaml-language-server
else
  echo "npm not found; yaml-language-server not installed."
fi
echo

echo ">>> Installing bash-language-server for coc-sh"
if command -v npm >/dev/null 2>&1; then
  npm install -g bash-language-server
else
  echo "npm not found; bash-language-server not installed."
fi
echo

echo "=== Done ==="
echo "Runtimes came from mise; language servers came from npm/go/cargo where appropriate."
echo "Global defaults from ${MISE_CONFIG_PATH} were applied into ${MISE_GLOBAL_CONFIG_PATH}."
echo "Other repos can still override them with their own local mise.toml files."
printf '\n'
printf 'Run `source ~/.bashrc` before proceeding.\n'
printf '\n'
