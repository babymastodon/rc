#!/usr/bin/env bash
set -Eeuo pipefail

# ============ SETTINGS ============
# Change if you want a different Nerd Font family.
NERD_FONT_NAME="${NERD_FONT_NAME:-Hack}"

# Common family names exposed by fontconfig for Hack Nerd Font:
FALLBACK_FAMILIES=(
  "Hack Nerd Font"
  "Hack Nerd Font Mono"
)

# Linux install location (user fonts)
LINUX_FONT_DIR="${LINUX_FONT_DIR:-$HOME/.local/share/fonts/NerdFonts/${NERD_FONT_NAME}}"
# Fontconfig rule location (user scope)
LINUX_FC_CONF_DIR="${HOME}/.config/fontconfig/conf.d"
LINUX_FC_CONF_FILE="${LINUX_FC_CONF_DIR}/10-nerd-fonts.conf"

msg()  { printf "\033[1;32m[+] %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m[!] %s\033[0m\n" "$*"; }
err()  { printf "\033[1;31m[✗] %s\033[0m\n" "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

# ============ macOS ============
install_macos() {
  msg "Detected macOS. Installing ${NERD_FONT_NAME} Nerd Font with Homebrew (no Chrome config)…"
  if ! have brew; then
    err "Homebrew not found. Install Homebrew first: https://brew.sh/"
    exit 1
  fi

  brew tap homebrew/cask-fonts >/dev/null 2>&1 || true

  local cask="font-$(echo "$NERD_FONT_NAME" | tr '[:upper:]' '[:lower:]')-nerd-font"
  if brew info --cask "$cask" >/dev/null 2>&1; then
    brew install --cask "$cask"
  else
    err "Could not find cask: $cask. Try: brew search nerd font"
    exit 1
  fi

  msg "Installed ${NERD_FONT_NAME} Nerd Font via Homebrew."
}

# ============ Linux ============
install_linux() {
  msg "Detected Linux. Installing ${NERD_FONT_NAME} Nerd Font for current user…"

  # Tool checks
  for t in curl unzip; do
    have "$t" || { err "Missing '$t'. Install it and re-run."; exit 1; }
  done

  local zip_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${NERD_FONT_NAME}.zip"

  mkdir -p "$LINUX_FONT_DIR"
  local tmpzip
  tmpzip="$(mktemp -t nerdfont-XXXXXX.zip)"

  msg "Downloading ${NERD_FONT_NAME} Nerd Font from official release…"
  curl -fsSL "$zip_url" -o "$tmpzip"

  msg "Installing into: $LINUX_FONT_DIR"
  unzip -o "$tmpzip" -d "$LINUX_FONT_DIR" >/dev/null
  rm -f "$tmpzip"

  # ---- Clean and rebuild user font cache (quietly) to avoid stale/invalid cache warnings ----
  rm -rf "$HOME/.cache/fontconfig" 2>/dev/null || true
  mkdir -p "$HOME/.cache/fontconfig"

  # Refresh caches without -v (suppresses “unwritable cache directory” noise)
  if have fc-cache; then
    fc-cache "$LINUX_FONT_DIR" || warn "fc-cache reported a non-fatal issue (dir)."
    fc-cache -r || warn "fc-cache reported a non-fatal issue (rebuild)."
  else
    warn "fc-cache not found; install fontconfig utilities to refresh cache."
  fi

  # Create fontconfig fallback rule
  mkdir -p "$LINUX_FC_CONF_DIR"
  {
    echo "<?xml version='1.0'?>"
    echo "<!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>"
    echo "<fontconfig>"
    for fam in sans-serif serif monospace; do
      echo "  <alias>"
      echo "    <family>${fam}</family>"
      echo "    <prefer>"
      for f in "${FALLBACK_FAMILIES[@]}"; do
        echo "      <family>${f}</family>"
      done
      echo "    </prefer>"
      echo "  </alias>"
    done
    echo "</fontconfig>"
  } > "$LINUX_FC_CONF_FILE"

  msg "Wrote fontconfig fallback rule: $LINUX_FC_CONF_FILE"

  # Verify visibility (quiet if not available)
  if have fc-list; then
    if grep -qi "${NERD_FONT_NAME} Nerd Font" <<<"$(fc-list 2>/dev/null)"; then
      msg "Verified: ${NERD_FONT_NAME} Nerd Font detected by fontconfig."
    else
      warn "Font not reported by fc-list yet. Run: fc-cache -r"
    fi
  fi
}

# ============ MAIN ============
case "$(uname -s)" in
  Darwin) install_macos ;;
  Linux)  install_linux ;;
  *) err "Unsupported OS: $(uname -s)"; exit 1 ;;
esac

msg "All done. Restart Chrome/Chromium to make sure it picks up the updated caches."
