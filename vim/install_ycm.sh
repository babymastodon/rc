#!/usr/bin/env bash
# setup-vim-ycm-fedora.sh
# Fedora 43 (DNF5) script to install Vim + YouCompleteMe with all completers.
# Changes requested:
#  - Do NOT retry failed build
#  - Do NOT install gopls to any bin
#  - Update YCM submodules to force a recent (fixed) gopls/x-tools
# Other behavior:
#  - Uses dnf5 (refresh once), sudo only when needed
#  - Installs base toolchains and runtimes (incl. Go) but does not preinstall gopls
#  - Installs global TypeScript (tsserver) for JS/TS support

set -euo pipefail

log()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

SUDO="sudo"
if [[ ${EUID:-$(id -u)} -eq 0 ]]; then SUDO=""; fi

INVOKING_USER="${SUDO_USER-$(id -un)}"
USER_HOME="$(getent passwd "$INVOKING_USER" | cut -d: -f6 || true)"
: "${USER_HOME:=$HOME}"

DNF_BIN="dnf5"

need_cmd() { command -v "$1" >/dev/null 2>&1; }

# ---------------- dnf5 helpers (flags go after subcommand) ----------------
dnf5_install() {
  # usage: dnf5_install pkg1 pkg2 ...
  local cmd=("${DNF_BIN}" install --assumeyes --skip-unavailable "$@")
  if [[ -z "$SUDO" ]]; then "${cmd[@]}" || true; else $SUDO "${cmd[@]}" || true; fi
}

# ---------------- system deps ----------------
install_system_deps() {
  log "Refreshing DNF metadata once..."
  if [[ -n "$SUDO" ]]; then
    $SUDO ${DNF_BIN} makecache --refresh || true
  else
    ${DNF_BIN} makecache --refresh || true
  fi

  log "Installing base tools and build deps (Fedora 43 / DNF5)..."
  BASE_PKGS=(
    vim git curl wget tar unzip
    python3 python3-pip python3-devel
    cmake ninja-build make gcc gcc-c++
    llvm llvm-devel clang clang-devel
    pkgconf-pkg-config
  )
  dnf5_install "${BASE_PKGS[@]}"

  RUNTIME_PKGS=(
    nodejs npm
    golang
    rust cargo rust-analyzer
    java-latest-openjdk-devel
    mono-devel
  )
  dnf5_install "${RUNTIME_PKGS[@]}"

  log "Installing optional eclipse-jdtls (Java LSP)..."
  dnf5_install eclipse-jdtls
}

# ---------------- language tooling (no gopls install) ----------------
install_lang_tools() {
  # JS/TS: ensure tsserver
  if need_cmd npm; then
    log "Installing global TypeScript (tsserver)..."
    if ! $SUDO npm install -g typescript >/dev/null 2>&1; then
      npm install -g typescript || warn "Could not install global TypeScript; tsserver may be missing."
    fi
  else
    warn "npm not found; JS/TS completer may be limited."
  fi

  # Intentionally NOT installing gopls (per request).
}

# ---------------- vim-plug ----------------
run_vimplug() {
  log "Running vim-plug (PlugInstall) for ${INVOKING_USER}..."
  if ! sudo -u "$INVOKING_USER" env HOME="$USER_HOME" bash -lc 'vim +PlugInstall +qall'; then
    warn "vim-plug failed. Check your vimrc and network connection."
  fi
}

# ---------------- locate YCM ----------------
find_ycm_dir() {
  local cands=(
    "$USER_HOME/.vim/plugged/YouCompleteMe"
    "$USER_HOME/.local/share/nvim/plugged/YouCompleteMe"
    "$USER_HOME/.vim/pack/plugins/start/YouCompleteMe"
  )
  for d in "${cands[@]}"; do
    [[ -d "$d" ]] && echo "$d" && return 0
  done
  return 1
}

# ---------------- update submodules to force recent gopls/x-tools ---------- #
update_ycm_submodules() {
  local y="$1"
  log "Updating YCM repository and submodules to latest..."
  # Safe pulls as the invoking user so the repo stays user-owned
  sudo -u "$INVOKING_USER" bash -lc "git -C '$y' fetch --tags origin || true"
  sudo -u "$INVOKING_USER" bash -lc "git -C '$y' pull --ff-only || true"
  sudo -u "$INVOKING_USER" bash -lc "git -C '$y' submodule update --init --recursive --remote"
}

# ---------------- clean stale Go caches inside YCM tree ----------------
clean_old_go_caches() {
  local y="$1"
  log "Cleaning YCM-local Go caches..."
  rm -rf "${y}/third_party/go/pkg/mod" \
         "${y}/third_party/go/bin" \
         "${y}/third_party/go/cache" 2>/dev/null || true
  if need_cmd go; then
    sudo -u "$INVOKING_USER" bash -lc 'go clean -modcache' || true
  fi
}

# ---------------- build YCM (single attempt, no retry) ----------------
build_ycm() {
  local ycm_dir
  if ! ycm_dir="$(find_ycm_dir)"; then
    err "YouCompleteMe directory not found after PlugInstall."
    exit 2
  fi
  log "Found YouCompleteMe at: ${ycm_dir}"

  # Ensure submodules are current to pull a fixed gopls/x-tools version
  update_ycm_submodules "$ycm_dir"

  # Clear caches so the build can't reuse bad x/tools
  clean_old_go_caches "$ycm_dir"

  # Show the Go that will be used (helpful for debugging)
  local GO_BIN GOROOT
  GO_BIN="$(sudo -u "$INVOKING_USER" bash -lc 'command -v go || true')"
  GOROOT="$(sudo -u "$INVOKING_USER" bash -lc 'go env GOROOT 2>/dev/null || true')"
  log "Using go at: ${GO_BIN:-<not found>}"
  sudo -u "$INVOKING_USER" bash -lc 'go version || true'

  local ncpu
  ncpu="$(getconf _NPROCESSORS_ONLN || echo 2)"

  log "Building YCM (single attempt) with --all --system-libclang..."
  pushd "$ycm_dir" >/dev/null

  # Minimal, consistent env; do NOT install gopls or modify PATH for it
  local build_env=(HOME="$USER_HOME" CMAKE_BUILD_PARALLEL_LEVEL="$ncpu" GO111MODULE=on GOWORK=off)
  [[ -n "$GOROOT" ]] && build_env+=("GOROOT=$GOROOT")

  # Single attempt only (per request). If it fails, exit non-zero.
  sudo -u "$INVOKING_USER" env "${build_env[@]}" \
    bash -lc 'python3 install.py --all --system-libclang --verbose'

  popd >/dev/null
}

# ---------------- notes ----------------
post_notes() {
  cat <<'EOF'

----------------------------------------------------------------------
✅ YouCompleteMe installation finished.

Notes:
  • Submodules were updated to ensure a recent gopls/x-tools is used by the build.
  • We did NOT install gopls ourselves (the YCM build handles Go tools).
  • If the build complains about x/tools versions, ensure your network/proxy isn't pinning old modules.

Language Support:
  • C/C++: system libclang
  • JS/TS: tsserver via TypeScript (installed globally)
  • Go: provided by YCM's build (no manual gopls install)
  • Rust: rust-analyzer
  • C#: Mono runtime

If Vim can't find completers, restart the shell and check :messages in Vim.
----------------------------------------------------------------------
EOF
}

# ---------------- main ----------------
main() {
  install_system_deps
  install_lang_tools
  run_vimplug
  build_ycm
  post_notes
  log "✅ All done!"
}

main "$@"

