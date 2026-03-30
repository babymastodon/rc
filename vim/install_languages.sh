#!/usr/bin/env bash

set -euo pipefail

echo "=== Setting up runtimes + CoC language servers (Linux & macOS) ==="

OS="$(uname -s)"

if [[ "$OS" == "Darwin" ]] && ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Install Homebrew first: https://brew.sh/" >&2
  exit 1
fi

print_shell_setup_guidance() {
  echo "Run \`./install.sh\` from the repo root, then \`source ~/.bashrc\`, then rerun this script." >&2
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
  if [ "$OS" = "Darwin" ]; then
    if command -v brew >/dev/null 2>&1; then
      echo "brew"
    else
      echo ""
    fi
  else
    if command -v apt >/dev/null 2>&1; then
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
  fi
}

PM="$(detect_pm)"

if [ -z "$PM" ]; then
  echo "No supported package manager detected (apt/pacman/dnf/yum/brew)."
  echo "Install Node, Rust, Go, and Clang manually, then rerun for the LSP installs."
  exit 1
fi

echo "Detected OS: $OS"
echo "Using package manager: $PM"
echo

GO_VERSION="1.26.1"

require_env_vars GOROOT GOPATH GOBIN NODEJS_HOME NPM_CONFIG_PREFIX

install_pkg() {
  case "$PM" in
    apt)
      sudo apt update
      sudo apt install -y "$@" ;;
    pacman)
      sudo pacman -Sy --noconfirm "$@" ;;
    dnf)
      sudo dnf install -y "$@" ;;
    yum)
      sudo yum install -y "$@" ;;
    brew)
      brew install "$@" ;;
  esac
}

detect_go_arch() {
  case "$(uname -m)" in
    x86_64|amd64)
      echo "amd64"
      ;;
    arm64|aarch64)
      echo "arm64"
      ;;
    *)
      echo "Unsupported arch for Go tarball: $(uname -m)" >&2
      return 1
      ;;
  esac
}

verify_sha256() {
  local file="$1" expected="$2" actual=""

  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$file" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  elif command -v openssl >/dev/null 2>&1; then
    actual="$(openssl dgst -sha256 "$file" | awk '{print $NF}')"
  else
    echo "Need sha256sum, shasum, or openssl to verify Go download." >&2
    return 1
  fi

  if [[ "$actual" != "$expected" ]]; then
    echo "SHA256 mismatch for $(basename "$file"): expected $expected, got $actual" >&2
    return 1
  fi
}

install_go_tarball() {
  local go_install_root install_dir goroot_parent goroot_backup

  if [[ -x "${GOROOT}/bin/go" ]]; then
    echo "Go already installed at ${GOROOT}."
    export PATH="${GOROOT}/bin:${GOBIN}:$PATH"
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    install_pkg curl
  fi

  local arch url sha256 tmp_tarball
  arch="$(detect_go_arch)"
  case "$OS:$arch" in
    Linux:amd64)
      url="https://go.dev/dl/go1.26.1.linux-amd64.tar.gz"
      sha256="031f088e5d955bab8657ede27ad4e3bc5b7c1ba281f05f245bcc304f327c987a"
      ;;
    Linux:arm64)
      url="https://go.dev/dl/go1.26.1.linux-arm64.tar.gz"
      sha256="a290581cfe4fe28ddd737dde3095f3dbeb7f2e4065cab4eae44dfc53b760c2f7"
      ;;
    Darwin:arm64)
      url="https://go.dev/dl/go1.26.1.darwin-arm64.tar.gz"
      sha256="353df43a7811ce284c8938b5f3c7df40b7bfb6f56cb165b150bc40b5e2dd541f"
      ;;
    Darwin:amd64)
      echo "Unsupported macOS architecture for pinned Go tarball: ${arch}" >&2
      return 1
      ;;
  esac

  go_install_root="$(dirname "$GOROOT")"
  install_dir="${go_install_root}/go-${GO_VERSION}-$(echo "$OS" | tr '[:upper:]' '[:lower:]')-${arch}"
  mkdir -p "$go_install_root" "$GOPATH" "$GOBIN"

  if [[ ! -x "${install_dir}/bin/go" ]]; then
    tmp_tarball="$(mktemp -t go.XXXXXX.tar.gz)"
    echo "Downloading Go ${GO_VERSION} (${arch})..."
    curl -fsSL "$url" -o "$tmp_tarball"
    verify_sha256 "$tmp_tarball" "$sha256"

    rm -rf "$install_dir"
    tar -xzf "$tmp_tarball" -C "$go_install_root"
    mv "${go_install_root}/go" "$install_dir"
    rm -f "$tmp_tarball"
  fi

  goroot_parent="$(dirname "$GOROOT")"
  mkdir -p "$goroot_parent"
  if [[ -e "$GOROOT" && ! -L "$GOROOT" && "$(cd "$GOROOT" 2>/dev/null && pwd -P)" != "$(cd "$install_dir" && pwd -P)" ]]; then
    goroot_backup="${GOROOT}.backup-before-go-${GO_VERSION}"
    rm -rf "$goroot_backup"
    mv "$GOROOT" "$goroot_backup"
    echo "Moved existing GOROOT directory to ${goroot_backup}."
  fi

  ln -sfn "$install_dir" "$GOROOT"
  export PATH="${GOROOT}/bin:${GOBIN}:$PATH"
}

install_node_tarball() {
  local node_parent node_backup

  if [[ -x "${NODEJS_HOME}/bin/node" ]]; then
    echo "Node.js already installed at ${NODEJS_HOME}."
    export PATH="${NODEJS_HOME}/bin:${NPM_CONFIG_PREFIX}/bin:$PATH"
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    install_pkg curl
  fi

  ARCH="$(uname -m)"
  case "$OS" in
    Darwin)
      PLATFORM="darwin"
      EXT="tar.gz"
      ;;
    *)
      PLATFORM="linux"
      EXT="tar.xz"
      ;;
  esac

  case "$ARCH" in
    x86_64|amd64) ARCH_TAG="x64" ;;
    arm64|aarch64) ARCH_TAG="arm64" ;;
    *)
      echo "Unsupported arch for Node.js tarball: $ARCH"
      return 1
      ;;
  esac

  NODE_PLATFORM="${PLATFORM}-${ARCH_TAG}"
  NODE_DIST="$(curl -fsSL https://nodejs.org/dist/latest/SHASUMS256.txt | awk -v p="$NODE_PLATFORM" -v e="$EXT" '$2 ~ ("node-v[0-9]+\\.[0-9]+\\.[0-9]+-" p "\\." e "$") {print $2; exit}')"
  if [ -z "$NODE_DIST" ]; then
    echo "Failed to determine latest Node.js tarball for ${NODE_PLATFORM}."
    return 1
  fi

  NODE_VERSION="$(echo "$NODE_DIST" | sed -E 's/^node-v([0-9]+\.[0-9]+\.[0-9]+)-.*$/\1/')"
  NODE_INSTALL_ROOT="$(dirname "$NODEJS_HOME")"
  NODE_DIR="$NODE_INSTALL_ROOT/node-v${NODE_VERSION}-${NODE_PLATFORM}"

  mkdir -p "$NODE_INSTALL_ROOT" "$NPM_CONFIG_PREFIX"

  if [ ! -d "$NODE_DIR" ]; then
    TMP_TARBALL="$(mktemp -t nodejs.XXXXXX.$EXT)"
    echo "Downloading Node.js ${NODE_VERSION} (${NODE_PLATFORM})..."
    curl -fsSL "https://nodejs.org/dist/latest/$NODE_DIST" -o "$TMP_TARBALL"
    tar -xf "$TMP_TARBALL" -C "$NODE_INSTALL_ROOT"
    rm -f "$TMP_TARBALL"
  fi

  node_parent="$(dirname "$NODEJS_HOME")"
  mkdir -p "$node_parent"
  if [[ -e "$NODEJS_HOME" && ! -L "$NODEJS_HOME" && "$(cd "$NODEJS_HOME" 2>/dev/null && pwd -P)" != "$(cd "$NODE_DIR" && pwd -P)" ]]; then
    node_backup="${NODEJS_HOME}.backup-before-node-${NODE_VERSION}"
    rm -rf "$node_backup"
    mv "$NODEJS_HOME" "$node_backup"
    echo "Moved existing NODEJS_HOME directory to ${node_backup}."
  fi

  ln -sf "$NODE_DIR" "$NODE_INSTALL_ROOT/current"
  export PATH="${NODEJS_HOME}/bin:${NPM_CONFIG_PREFIX}/bin:$PATH"
}

install_rustup() {
  if command -v rustup >/dev/null 2>&1; then
    echo "rustup already installed."
    return 0
  fi

  if command -v rustc >/dev/null 2>&1; then
    echo "rustc already installed; skipping rustup."
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    install_pkg curl
  fi

  echo "Installing Rust via rustup (no PATH modification)."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
}

#############################
# Core runtimes / toolchains
#############################

echo ">>> Installing core runtimes"

case "$PM" in
  apt)
    install_node_tarball
    install_rustup
    install_go_tarball
    command -v clang >/dev/null 2>&1 || install_pkg clang
    command -v clangd >/dev/null 2>&1 || install_pkg clangd || true
    ;;
  pacman)
    install_node_tarball
    install_rustup
    install_go_tarball
    command -v clang >/dev/null 2>&1 || install_pkg clang
    command -v clangd >/dev/null 2>&1 || install_pkg clang
    ;;
  dnf|yum)
    install_node_tarball
    install_rustup
    install_go_tarball
    command -v clang >/dev/null 2>&1 || install_pkg clang
    command -v clangd >/dev/null 2>&1 || install_pkg clang-tools-extra || install_pkg clangd || true
    ;;
  brew)
    install_node_tarball
    install_rustup
    install_go_tarball
    if ! command -v clang >/dev/null 2>&1 || ! command -v clangd >/dev/null 2>&1; then
      install_pkg llvm
      echo 'Note: on macOS with llvm via brew, you may need:'
      echo '  export PATH="$(brew --prefix llvm)/bin:$PATH"'
    fi
    ;;
esac

echo
echo "Core runtimes done."
echo
echo "Make sure runtime bin dirs are on PATH:"
echo "  Go:    \$GOROOT/bin and \$GOBIN"
echo "  Node:  \$NODEJS_HOME/bin"
echo "  npm:   \$NPM_CONFIG_PREFIX/bin"
echo "  Cargo: \$HOME/.cargo/bin"
echo

#############################
# Language servers / tools
# Prefer runtime installers
#############################

### coc-pyright -> Pyright (npm)
echo ">>> Installing Pyright for coc-pyright (npm preferred)"
export PATH="${NODEJS_HOME}/bin:${NPM_CONFIG_PREFIX}/bin:$PATH"
if command -v npm >/dev/null 2>&1; then
  npm config set prefix "${NPM_CONFIG_PREFIX}"
  npm install -g pyright
else
  echo "npm not found; Pyright not installed."
fi
echo

### coc-rust-analyzer -> rust-analyzer (prefer cargo, fallback pkg)
echo ">>> Installing rust-analyzer for coc-rust-analyzer (cargo preferred)"
if [ -d "$HOME/.cargo/bin" ]; then
  export PATH="$HOME/.cargo/bin:$PATH"
fi
if command -v rust-analyzer >/dev/null 2>&1; then
  echo "rust-analyzer already installed."
else
  if command -v cargo >/dev/null 2>&1; then
    # build from source (may take a while)
    if cargo install rust-analyzer; then
      echo "rust-analyzer installed via cargo."
    else
      echo "cargo install rust-analyzer failed; install it manually from GitHub."
    fi
  else
    echo "cargo not found; rust-analyzer not installed."
  fi
fi
echo

### coc-go -> gopls (go install only)
echo ">>> Installing gopls for coc-go (go install only)"
export PATH="${GOROOT}/bin:${GOBIN}:$PATH"
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

### coc-clangd -> clangd (runtime = clang toolchain, already pkg-managed)
echo ">>> Checking clangd for coc-clangd"
if command -v clangd >/dev/null 2>&1; then
  echo "clangd is installed."
else
  echo "clangd still not found; you may need to install it manually for C/C++ support."
fi
echo

### coc-tsserver -> TypeScript + typescript-language-server (npm)
echo ">>> Installing TypeScript + typescript-language-server for coc-tsserver (npm preferred)"
export PATH="${NODEJS_HOME}/bin:${NPM_CONFIG_PREFIX}/bin:$PATH"
if command -v npm >/dev/null 2>&1; then
  npm install -g typescript typescript-language-server
else
  echo "npm not found; tsserver LSP not installed."
fi
echo

### coc-yaml -> yaml-language-server (npm)
echo ">>> Installing yaml-language-server for coc-yaml (npm preferred)"
export PATH="${NODEJS_HOME}/bin:${NPM_CONFIG_PREFIX}/bin:$PATH"
if command -v npm >/dev/null 2>&1; then
  npm install -g yaml-language-server
else
  echo "npm not found; yaml-language-server not installed."
fi
echo

### coc-sh -> bash-language-server (npm)
echo ">>> Installing bash-language-server for coc-sh (npm preferred)"
export PATH="${NODEJS_HOME}/bin:${NPM_CONFIG_PREFIX}/bin:$PATH"
if command -v npm >/dev/null 2>&1; then
  npm install -g bash-language-server
else
  echo "npm not found; bash-language-server not installed."
fi
echo

echo "=== Done ==="
echo "Runtimes came from the package manager; language servers came from npm/go/cargo where possible."
echo "Ensure your global npm bin, Go bin, and Cargo bin dirs are on PATH."
