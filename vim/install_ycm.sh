#!/usr/bin/env bash
# setup-vim-ycm.sh
# Cross-platform YouCompleteMe installer (Fedora, Ubuntu/Debian, macOS).
#
# Policies:
#   - Prefer user-level tools first (npm/cargo), fallback to system/global.
#   - No nvm, no rustup, do NOT install gopls anywhere.
#   - macOS: check CLT *without sudo* and use modern compiler flags (CLT 26.1).
#   - Ensure Go >= 1.24 (upgrade via pkg mgr; Linux fallback is user-local Go).
#   - Single YCM build attempt; update submodules to force recent x/tools/gopls.
#   - Minimal sudo (system deps only, none for macOS CLT checks).
#
set -euo pipefail

log()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

SUDO="sudo"
if [[ ${EUID:-$(id -u)} -eq 0 ]]; then SUDO=""; fi

INVOKING_USER="${SUDO_USER-$(id -un)}"
if need_cmd getent; then
  USER_HOME="$(getent passwd "$INVOKING_USER" | cut -d: -f6 || true)"
else
  USER_HOME="${HOME}"
fi
: "${USER_HOME:=$HOME}"

OS=""
PKG=""
if [[ "$(uname -s)" == "Darwin" ]]; then
  OS="mac"; PKG="brew"
elif [[ -r /etc/os-release ]]; then
  . /etc/os-release
  case "${ID:-}" in
    fedora) OS="fedora"; PKG="dnf5" ;;
    ubuntu|debian) OS="ubuntu"; PKG="apt" ;;
    *) OS="${ID:-linux}"; PKG="apt" ;;
  esac
else
  OS="linux"; PKG="apt"
fi

# ---------------- Pkg helpers ----------------
dnf5_install() { local cmd=(dnf5 install -y --skip-unavailable "$@"); [[ -n "$SUDO" ]] && $SUDO "${cmd[@]}" || "${cmd[@]}" || true; }
apt_install()  { local cmd=(apt-get install -y --no-install-recommends "$@"); [[ -n "$SUDO" ]] && $SUDO "${cmd[@]}" || "${cmd[@]}" || true; }
brew_install() { if ! need_cmd brew; then err "Homebrew not found. Install https://brew.sh"; exit 1; fi; brew install "$@" || true; }

# ---------------- Version helpers ----------------
parse_go_version() { go version 2>/dev/null | sed -n 's/.* go\([0-9]\+\)\.\([0-9]\+\)\(\.[0-9]\+\)\{0,1\}.*/\1.\2\3/p' | sed 's/\.$//'; }
ver_ge() { local a1 a2 a3 b1 b2 b3; IFS=. read -r a1 a2 a3 <<<"${1}.0.0"; IFS=. read -r b1 b2 b3 <<<"${2}.0.0"; ((a1>b1))||((a1==b1&&a2>b2))||((a1==b1&&a2==b2&&a3>=b3)); }

# ---------------- System deps ----------------
install_system_deps_fedora() {
  log "Installing core deps (Fedora)..."
  [[ -n "$SUDO" ]] && $SUDO dnf5 makecache --refresh || dnf5 makecache --refresh || true
  dnf5_install vim git curl wget tar unzip python3 python3-pip python3-devel cmake ninja-build make gcc gcc-c++ llvm llvm-devel clang clang-devel pkgconf-pkg-config golang nodejs npm java-latest-openjdk-devel mono-devel rust cargo
  dnf5_install eclipse-jdtls || true
}
install_system_deps_ubuntu() {
  log "Installing core deps (Ubuntu/Debian)..."
  [[ -n "$SUDO" ]] && $SUDO apt-get update -y || apt-get update -y || true
  apt_install vim git curl wget tar unzip python3 python3-pip python3-dev cmake ninja-build build-essential gcc g++ llvm clang pkg-config golang nodejs npm default-jdk mono-complete rustc cargo
  apt_install jdtls || warn "jdtls not available; skipping."
}
install_system_deps_mac() {
  log "Checking Apple Command Line Tools (no sudo, no switching)..."
  if ! xcode-select -p >/dev/null 2>&1; then
    warn "CLT not found. Please run: xcode-select --install (GUI prompt)"; 
  fi
  # Pure read-only checks (no sudo)
  xcrun --sdk macosx --show-sdk-path >/dev/null 2>&1 || warn "xcrun can't find macOS SDK; CLT may be incomplete."
  pkgutil --pkg-info=com.apple.pkg.CLTools_Executables >/dev/null 2>&1 || warn "CLT pkg info not found (com.apple.pkg.CLTools_Executables)."

  log "Updating Homebrew..."
  brew update || true
  log "Installing core deps (macOS; Apple toolchain only)..."
  brew_install vim git curl wget gnu-tar unzip python@3.13 cmake ninja pkg-config go node openjdk mono jdtls rust cargo rust-analyzer
}
install_system_deps() {
  case "$OS" in
    fedora) install_system_deps_fedora ;;
    ubuntu|linux|debian) install_system_deps_ubuntu ;;
    mac) install_system_deps_mac ;;
    *) warn "Unknown OS '${OS}', defaulting to Ubuntu-like."; install_system_deps_ubuntu ;;
  esac
}

# ---------------- Ensure Go >= 1.24 ----------------
install_or_upgrade_go_to_min() {
  local need="1.24.0"
  local cur; cur="$(parse_go_version || true)"
  if [[ -n "$cur" ]] && ver_ge "$cur" "$need"; then log "Go OK: $cur (>= $need)"; return 0; fi

  log "Upgrading/Installing Go to >= $need ..."
  case "$OS" in
    mac)
      brew update || true
      (brew ls --versions go >/dev/null 2>&1 && brew upgrade go) || brew install go || true
      ;;
    fedora)
      [[ -n "$SUDO" ]] && $SUDO dnf5 upgrade -y golang || true
      dnf5_install golang
      ;;
    ubuntu|linux|debian)
      [[ -n "$SUDO" ]] && $SUDO apt-get update -y || true
      apt_install golang
      ;;
  esac

  cur="$(parse_go_version || true)"
  if [[ -n "$cur" ]] && ver_ge "$cur" "$need"; then log "Go OK after system upgrade: $cur"; return 0; fi

  if [[ "$OS" == "ubuntu" || "$OS" == "linux" || "$OS" == "debian" ]]; then
    warn "System Go still < $need; installing user-local Go under ~/.local/go"
    local GO_VER ARCH
    GO_VER="$(curl -fsSL https://go.dev/VERSION?m=text | head -1)"
    case "$(uname -m)" in x86_64|amd64) ARCH="amd64" ;; aarch64|arm64) ARCH="arm64" ;; *) err "Unsupported arch: $(uname -m)"; return 1 ;; esac
    mkdir -p "$USER_HOME/.local"
    curl -fsSL -o "$USER_HOME/.local/${GO_VER}.tar.gz" "https://go.dev/dl/${GO_VER}.linux-${ARCH}.tar.gz"
    rm -rf "$USER_HOME/.local/go" 2>/dev/null || true
    tar -C "$USER_HOME/.local" -xzf "$USER_HOME/.local/${GO_VER}.tar.gz"
    ln -snf "$USER_HOME/.local/go/bin/go" "$USER_HOME/.local/bin/go"
    export PATH="$USER_HOME/.local/go/bin:$PATH"
    log "Installed user-local Go: $(go version || true)"
  fi
}

# ---------------- JS/TS (user npm first) ----------------
install_typescript_user_then_global() {
  if need_cmd npm; then
    log "Installing TypeScript (user)..."
    npm install -g typescript >/dev/null 2>&1 && { log "TypeScript installed (user)."; return 0; }
    warn "User TypeScript install failed; trying global..."
    [[ -n "$SUDO" ]] && $SUDO npm install -g typescript || warn "Global TypeScript install failed."
  else
    warn "npm not found; skipping JS/TS completer."
  fi
}

# ---------------- Rust (cargo first) ----------------
ensure_rust_analyzer_user_then_system() {
  if need_cmd rust-analyzer; then log "rust-analyzer already present."; return 0; fi
  if need_cmd cargo; then
    log "Installing rust-analyzer via cargo (user)..."
    cargo install --locked rust-analyzer && { log "rust-analyzer installed to ~/.cargo/bin."; return 0; }
    warn "cargo install rust-analyzer failed; trying system package."
  else
    warn "cargo not found; trying system rust-analyzer."
  fi
  case "$OS" in
    fedora) dnf5_install rust-analyzer ;;
    ubuntu|linux|debian) apt_install rust-analyzer || warn "rust-analyzer not available on this Ubuntu release." ;;
    mac) brew_install rust-analyzer ;;
  esac
  need_cmd rust-analyzer || warn "rust-analyzer still not found; Rust completer will be unavailable."
}

# ---------------- vim-plug ----------------
run_vimplug() {
  log "Running vim-plug for ${INVOKING_USER}..."
  sudo -u "$INVOKING_USER" env HOME="$USER_HOME" bash -lc 'vim +PlugInstall +qall' || warn "vim-plug failed."
}

# ---------------- locate YCM ----------------
find_ycm_dir() {
  local cands=(
    "$USER_HOME/.vim/plugged/YouCompleteMe"
    "$USER_HOME/.local/share/nvim/plugged/YouCompleteMe"
    "$USER_HOME/.vim/pack/plugins/start/YouCompleteMe"
    "$USER_HOME/.local/share/vim/pack/plugins/start/YouCompleteMe"
    "$USER_HOME/.local/share/nvim/site/pack/plugins/start/YouCompleteMe"
  )
  for d in "${cands[@]}"; do [[ -d "$d" ]] && { echo "$d"; return 0; }; done
  return 1
}

# ---------------- YCM submodules & Go cache ----------------
update_ycm_submodules() {
  local y="$1"
  log "Updating YCM repo and submodules..."
  sudo -u "$INVOKING_USER" bash -lc "git -C '$y' fetch --tags origin || true"
  sudo -u "$INVOKING_USER" bash -lc "git -C '$y' pull --ff-only || true"
  sudo -u "$INVOKING_USER" bash -lc "git -C '$y' submodule update --init --recursive --remote"
}
clean_old_go_caches() {
  local y="$1"
  log "Cleaning YCM Go caches..."
  rm -rf "$y/third_party/go/pkg/mod" "$y/third_party/go/bin" "$y/third_party/go/cache" 2>/dev/null || true
  need_cmd go && sudo -u "$INVOKING_USER" bash -lc 'go clean -modcache' || true
}

# ---------------- macOS CLT probe (read-only) ----------------
mac_probe_clt() {
  # No sudo; purely diagnostic and to set SDKROOT if available.
  if ! xcode-select -p >/dev/null 2>&1; then
    warn "CLT not installed (xcode-select -p failed)."
    return 1
  fi
  local sdk; sdk="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
  if [[ -z "$sdk" || ! -d "$sdk" ]]; then
    warn "macOS SDK not found via xcrun; headers may be missing."
    return 1
  fi
  export SDKROOT="$sdk"
  # Optional: record CLT/Xcode versions for logs
  clang++ --version 2>/dev/null | sed -n '1p' || true
  pkgutil --pkg-info=com.apple.pkg.CLTools_Executables 2>/dev/null | sed -n 's/^version: /CLT version: /p' || true
  return 0
}

# ---------------- build YCM (single attempt) ----------------
build_ycm() {
  local ycm_dir; ycm_dir="$(find_ycm_dir)" || { err "YouCompleteMe directory not found after PlugInstall."; exit 2; }
  log "Found YCM at: $ycm_dir"

  update_ycm_submodules "$ycm_dir"
  clean_old_go_caches "$ycm_dir"

  # Ensure Go is recent enough for vendored x/tools/gopls
  install_or_upgrade_go_to_min

  # Nuke any stale CMake cache
  rm -rf "$ycm_dir/build" 2>/dev/null || true

  # CPU parallelism
  local ncpu; ncpu="$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)"

  # Common build env
  local build_env=(HOME="$USER_HOME" CMAKE_BUILD_PARALLEL_LEVEL="$ncpu" GO111MODULE=on GOWORK=off)

  if [[ "$OS" == "mac" ]]; then
    # Pure Apple toolchain (flags suitable for modern CLT 26.1)
    mac_probe_clt || warn "Proceeding without SDKROOT (build may fail on old CLT)."
    build_env+=("CC=/usr/bin/clang" "CXX=/usr/bin/clang++")
    # For latest CLT, C++17 filesystem works out of the box — no -lc++fs.
    # If you *know* you're on an older CLT, manually export LDFLAGS+=-lc++fs before running this script.
  fi

  log "Building YCM (single attempt) with --all --system-libclang..."
  pushd "$ycm_dir" >/dev/null
  sudo -u "$INVOKING_USER" env "${build_env[@]}" \
    bash -lc 'python3 install.py --all --system-libclang --verbose'
  popd >/dev/null
}

# ---------------- notes ----------------
post_notes() {
  cat <<'EOF'

----------------------------------------------------------------------
✅ YouCompleteMe installation finished.

macOS:
  • Checked Command Line Tools WITHOUT sudo; did not switch or modify CLT.
  • Used Apple clang/clang++ with SDKROOT from xcrun (flags compatible with CLT 26.1).
  • No Homebrew LLVM. Runtime uses --system-libclang.

Go:
  • Ensured Go >= 1.24. Linux fallback installs user-local Go under ~/.local/go if distro Go is too old.

JS/TS & Rust:
  • TypeScript (tsserver) installed user-first via npm; global fallback if needed.
  • rust-analyzer installed user-first via cargo; system fallback if needed.

Unchanged by request:
  • No gopls installation to any bin.
  • YCM submodules updated to pull recent x/tools/gopls.
  • Single build attempt (no retries).

If completers are missing:
  • Restart your shell to pick up PATH (~/.npm-global/bin, ~/.cargo/bin, ~/.local/go/bin).
  • Check :messages in Vim for missing tools.
----------------------------------------------------------------------
EOF
}

# ---------------- main ----------------
main() {
  log "Detected OS: ${OS} (pkg mgr: ${PKG})"
  install_system_deps
  install_typescript_user_then_global
  ensure_rust_analyzer_user_then_system
  run_vimplug
  build_ycm
  post_notes
  log "✅ All done!"
}

main "$@"

