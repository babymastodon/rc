#!/usr/bin/env bash

set -euo pipefail

echo "=== Setting up runtimes + CoC language servers (Linux & macOS) ==="

OS="$(uname -s)"

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
  echo "Install Node, Rust, Go, Java, and Clang manually, then rerun for the LSP installs."
  exit 1
fi

echo "Detected OS: $OS"
echo "Using package manager: $PM"
echo

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

install_fnm() {
  if command -v fnm >/dev/null 2>&1; then
    echo "fnm already installed."
  else
    if ! command -v curl >/dev/null 2>&1; then
      install_pkg curl
    fi
    if ! command -v unzip >/dev/null 2>&1; then
      install_pkg unzip
    fi
    echo "Installing fnm (Node.js version manager) to \$HOME..."
    export FNM_DIR="$HOME/.local/share/fnm"
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
  fi

  export FNM_DIR="$HOME/.local/share/fnm"
  if [ -d "$FNM_DIR" ]; then
    export PATH="$FNM_DIR:$PATH"
  fi
  if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --shell=bash)"
  fi

  if ! command -v node >/dev/null 2>&1; then
    echo "Installing latest Node.js via fnm..."
    fnm install --latest
    LATEST_NODE="$(fnm list | sed -E 's/^[* ]+//' | tail -n 1)"
    if [ -n "$LATEST_NODE" ]; then
      fnm use "$LATEST_NODE"
      fnm default "$LATEST_NODE"
    fi
  fi
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

echo ">>> Installing core runtimes (system package manager + rustup for Rust)"

case "$PM" in
  apt)
    install_fnm
    install_rustup
    command -v go    >/dev/null 2>&1 || install_pkg golang
    command -v java  >/dev/null 2>&1 || install_pkg default-jdk
    command -v clang >/dev/null 2>&1 || install_pkg clang
    command -v clangd >/dev/null 2>&1 || install_pkg clangd || true
    ;;
  pacman)
    install_fnm
    install_rustup
    command -v go    >/dev/null 2>&1 || install_pkg go
    command -v java  >/devnull 2>&1 || install_pkg jdk-openjdk || true
    command -v clang >/dev/null 2>&1 || install_pkg clang
    command -v clangd >/dev/null 2>&1 || install_pkg clang
    ;;
  dnf|yum)
    install_fnm
    install_rustup
    command -v go    >/dev/null 2>&1 || install_pkg golang
    command -v java  >/dev/null 2>&1 || install_pkg java-17-openjdk-devel || install_pkg java-11-openjdk-devel
    command -v clang >/dev/null 2>&1 || install_pkg clang
    command -v clangd >/dev/null 2>&1 || install_pkg clang-tools-extra || install_pkg clangd || true
    ;;
  brew)
    install_fnm
    install_rustup
    command -v go    >/dev/null 2>&1 || install_pkg go
    command -v java  >/dev/null 2>&1 || install_pkg openjdk
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
echo "  Go:    \$GOPATH/bin or \$HOME/go/bin"
echo "  Cargo: \$HOME/.cargo/bin"
echo

#############################
# Language servers / tools
# Prefer runtime installers
#############################

### coc-pyright -> Pyright (npm)
echo ">>> Installing Pyright for coc-pyright (npm preferred)"
if command -v npm >/dev/null 2>&1; then
  npm config set prefix "${HOME}/.npm-global"
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
      echo "cargo install rust-analyzer failed; trying package manager as fallback..."
      install_pkg rust-analyzer || echo "rust-analyzer not available via package manager; install manually from GitHub."
    fi
  else
    echo "cargo not found; trying package manager for rust-analyzer..."
    install_pkg rust-analyzer || echo "rust-analyzer not available via package manager; install manually from GitHub."
  fi
fi
echo

### coc-go -> gopls (go install preferred)
echo ">>> Installing gopls for coc-go (go install preferred)"
if command -v go >/dev/null 2>&1; then
  if go install golang.org/x/tools/gopls@latest; then
    echo "gopls installed via go install."
  else
    echo "go install gopls failed; trying package manager as fallback..."
    install_pkg gopls || echo "gopls not available via package manager."
  fi
else
  echo "Go not found; trying package manager for gopls..."
  install_pkg gopls || echo "gopls not available via package manager."
fi
echo

### coc-java -> JDT LS
echo ">>> Installing JDT Language Server for coc-java (no good runtime installer; using pkg manager if available)"
case "$PM" in
  apt)
    install_pkg jdtls || echo "jdtls not available; you may need manual Eclipse JDT LS setup."
    ;;
  pacman)
    install_pkg jdtls || echo "jdtls not available; you may need manual Eclipse JDT LS setup."
    ;;
  dnf|yum)
    install_pkg eclipse-jdt || echo "Eclipse JDT LS not easily packaged; manual setup may be required."
    ;;
  brew)
    install_pkg jdtls || echo "brew jdtls install failed; manual JDT LS setup may be needed."
    ;;
esac
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
if command -v npm >/dev/null 2>&1; then
  npm install -g typescript typescript-language-server
else
  echo "npm not found; tsserver LSP not installed."
fi
echo

### coc-yaml -> yaml-language-server (npm)
echo ">>> Installing yaml-language-server for coc-yaml (npm preferred)"
if command -v npm >/dev/null 2>&1; then
  npm install -g yaml-language-server
else
  echo "npm not found; yaml-language-server not installed."
fi
echo

### coc-sh -> bash-language-server (npm)
echo ">>> Installing bash-language-server for coc-sh (npm preferred)"
if command -v npm >/dev/null 2>&1; then
  npm install -g bash-language-server
else
  echo "npm not found; bash-language-server not installed."
fi
echo

echo "=== Done ==="
echo "Runtimes came from the package manager; language servers came from npm/go/cargo where possible."
echo "Ensure your global npm bin, Go bin, and Cargo bin dirs are on PATH."
