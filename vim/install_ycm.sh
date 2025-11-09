#!/usr/bin/env bash
# setup-vim-ycm-fedora.sh
# Installs Vim + YouCompleteMe with "all completers" on Fedora.
# - Assumes vimrc uses vim-plug and includes YouCompleteMe
# - Elevates to sudo only when necessary

set -euo pipefail

log()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

SUDO="sudo"
if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  SUDO=""  # already root
fi

# Detect the real user (who will own plugin builds)
INVOKING_USER="${SUDO_USER-$(id -un)}"
USER_HOME="$(getent passwd "$INVOKING_USER" | cut -d: -f6)"

dnf_install() {
  # Wrapper: install packages, ignore ones that aren't found if '--best' fails
  # Usage: dnf_install pkg1 pkg2 ...
  if [[ -z "$SUDO" ]]; then
    dnf -y install "$@" || true
  else
    $SUDO dnf -y install "$@" || true
  fi
}

dnf_groupinstall() {
  if [[ -z "$SUDO" ]]; then
    dnf -y groupinstall "$@" || true
  else
    $SUDO dnf -y groupinstall "$@" || true
  fi
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

install_system_deps() {
  log "Installing development toolchain (sudo when needed)..."
  dnf_groupinstall "Development Tools"

  # Core editors/tools
  dnf_install vim git curl wget tar unzip

  # Build toolchain + Python dev headers
  dnf_install python3 python3-pip python3-devel \
              cmake ninja-build make gcc gcc-c++ \
              llvm llvm-devel clang clang-devel pkgconf-pkg-config

  # Runtimes for YCM completers
  dnf_install nodejs npm golang rust cargo rust-analyzer \
              java-latest-openjdk-devel mono-devel

  # Java LSP used by some setups; Fedora package name is eclipse-jdtls (optional)
  if ! dnf_install eclipse-jdtls; then
    warn "eclipse-jdtls not available in your enabled repos; continuing without it."
  fi

  # Optional: dotnet SDK is not in Fedora base; skipping (Mono covers C# for YCM).
}

install_lang_tools() {
  # Ensure tsserver (TypeScript) available globally
  if need_cmd npm; then
    log "Ensuring global TypeScript (tsserver) is present..."
    $SUDO npm install -g typescript >/dev/null 2>&1 || npm install -g typescript || warn "Could not install global TypeScript."
  else
    warn "npm not found; JS/TS completer may be limited."
  fi

  # Go: install gopls (nice to have)
  if need_cmd go; then
    log "Installing gopls (optional but recommended for Go)..."
    GOPATH="${GOPATH:-${USER_HOME}/go}"
    GOBIN="${GOBIN:-${GOPATH}/bin}"
    mkdir -p "$GOBIN"
    sudo -u "$INVOKING_USER" env HOME="$USER_HOME" GOPATH="$GOPATH" GOBIN="$GOBIN" \
      bash -lc 'go install golang.org/x/tools/gopls@latest' || warn "gopls installation skipped."
  fi
}

run_vimplug() {
  log "Running vim-plug (PlugInstall) for ${INVOKING_USER}..."
  # Headless install of plugins
  sudo -u "$INVOKING_USER" env HOME="$USER_HOME" bash -lc 'vim +PlugInstall +qall' || \
    warn "PlugInstall reported non-zero exit; verify your vimrc and network."
}

find_ycm_dir() {
  local cands=(
    "$USER_HOME/.vim/plugged/YouCompleteMe"
    "$USER_HOME/.local/share/nvim/plugged/YouCompleteMe"
    "$USER_HOME/.vim/pack/plugins/start/YouCompleteMe"
  )
  for d in "${cands[@]}"; do
    if [[ -d "$d" ]]; then
      echo "$d"
      return 0
    fi
  done
  return 1
}

build_ycm() {
  local ycm_dir
  if ! ycm_dir="$(find_ycm_dir)"; then
    err "Could not locate YouCompleteMe after PlugInstall. Ensure the Plug is present and re-run."
    exit 2
  fi
  log "Found YouCompleteMe at: ${ycm_dir}"

  local ncpu
  ncpu="$(getconf _NPROCESSORS_ONLN || echo 2)"

  log "Building YCM with all completers using system libclang..."
  pushd "$ycm_dir" >/dev/null

  # Build as the invoking user (no root-owned artifacts in $HOME)
  if ! sudo -u "$INVOKING_USER" env HOME="$USER_HOME" CMAKE_BUILD_PARALLEL_LEVEL="$ncpu" \
      bash -lc 'python3 install.py --all --system-libclang'; then
    warn "YCM --all build failed; retrying with explicit completer flags..."
    sudo -u "$INVOKING_USER" env HOME="$USER_HOME" CMAKE_BUILD_PARALLEL_LEVEL="$ncpu" \
      bash -lc 'python3 install.py --clangd-completer --ts-completer --go-completer --rust-completer --cs-completer --system-libclang' || {
        err "YCM build failed. Check clang/mono/npm/go/rust setup above."
        exit 3
      }
  fi

  popd >/dev/null
}

post_notes() {
  cat <<'EOF'

----------------------------------------------------------------------
YouCompleteMe installation finished.

Check per-language support:
  - C/C++: clang/llvm + libclang (we used --system-libclang).
  - JS/TS: tsserver (global TypeScript installed via npm).
  - Go: gopls recommended (attempted install).
  - Rust: rust-analyzer installed via dnf.
  - C#: Mono installed via dnf (dotnet SDK optional).

If Vim can’t find completers, reopen Vim or verify your runtime paths.
----------------------------------------------------------------------
EOF
}

main() {
  install_system_deps
  install_lang_tools
  run_vimplug
  build_ycm
  post_notes
  log "Done!"
}

main "$@"
