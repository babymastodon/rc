#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

COHERE_MODEL="cohere-transcribe-q4f16"
COHERE_REPO="https://huggingface.co/onnx-community/cohere-transcribe-03-2026-ONNX"
VOXTYPE_VERSION="0.7.4"
VOXTYPE_DMG_URL="https://github.com/peteonrails/voxtype/releases/download/v${VOXTYPE_VERSION}/voxtype-${VOXTYPE_VERSION}-macos-universal.dmg"
VOXTYPE_SOURCE_URL="https://github.com/peteonrails/voxtype"
VOXTYPE_SOURCE_FEATURES="cohere,gpu-metal,ort/pkg-config"

CONFIG_SRC="$REPO_ROOT/voxtype/config.macos.toml"
CONFIG_DEST="$HOME/Library/Application Support/voxtype/config.toml"
MODEL_BASE_DIR="$HOME/Library/Application Support/io.voxtype.voxtype/models"
MODEL_DIR="$MODEL_BASE_DIR/${COHERE_MODEL}"
LEGACY_MODEL_DIR="$HOME/Library/Application Support/voxtype/models/${COHERE_MODEL}"
VOXTYPE_BIN_DIR="$HOME/.local/share/voxtype/bin"
VOXTYPE_BIN="$VOXTYPE_BIN_DIR/voxtype-${VOXTYPE_VERSION}-macos-universal"
VOXTYPE_COHERE_ROOT="$HOME/.local/share/voxtype/source-cohere-${VOXTYPE_VERSION}"
VOXTYPE_COHERE_BIN="$VOXTYPE_COHERE_ROOT/bin/voxtype"
VOXTYPE_LINK="$HOME/.local/bin/voxtype"
LAUNCH_AGENT_LABEL="io.voxtype.daemon"
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/${LAUNCH_AGENT_LABEL}.plist"
LOG_DIR="$HOME/Library/Logs/voxtype"

log() { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

require_command() {
  local cmd="$1"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    err "Missing required command: ${cmd}"
    exit 1
  fi
}

preflight() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    err "This installer expects macOS."
    exit 1
  fi

  if [[ "$(uname -m)" != "arm64" ]]; then
    err "Voxtype's macOS build is intended for Apple Silicon."
    exit 1
  fi

  require_command curl
  require_command hdiutil
  require_command ditto
  require_command plutil
  require_command launchctl
}

installed_voxtype_version() {
  local voxtype_bin

  if voxtype_bin="$(find_voxtype_bin 2>/dev/null)"; then
    "$voxtype_bin" --version 2>/dev/null | awk '{print $2}'
  fi
}

remove_stale_homebrew_cask() {
  local cask_version

  if ! command -v brew >/dev/null 2>&1; then
    return
  fi

  if ! brew list --cask voxtype >/dev/null 2>&1; then
    return
  fi

  cask_version="$(brew list --cask --versions voxtype 2>/dev/null | awk '{print $2}')"
  if [[ "$cask_version" == "$VOXTYPE_VERSION" ]]; then
    return
  fi

  warn "Removing stale Homebrew Voxtype cask ${cask_version:-unknown}; installing official ${VOXTYPE_VERSION} release directly."
  brew uninstall --cask voxtype || warn "Could not remove stale Homebrew cask record."
}

find_voxtype_bin() {
  local candidate
  for candidate in \
    "$VOXTYPE_BIN" \
    "/Applications/Voxtype.app/Contents/MacOS/voxtype-bin" \
    "/Applications/Voxtype.app/Contents/MacOS/voxtype"
  do
    if [[ -x "$candidate" ]]; then
      printf "%s\n" "$candidate"
      return 0
    fi
  done

  if command -v voxtype >/dev/null 2>&1; then
    command -v voxtype
    return 0
  fi

  return 1
}

install_voxtype_binary() {
  local current_version dmg_path mount_dir mounted_bin

  current_version="$(installed_voxtype_version || true)"
  if [[ "$current_version" == "$VOXTYPE_VERSION" && -x "$VOXTYPE_BIN" ]]; then
    log "Voxtype ${VOXTYPE_VERSION} binary is already installed."
    return
  fi

  dmg_path="/private/tmp/voxtype-${VOXTYPE_VERSION}-macos-universal.dmg"
  mount_dir="/private/tmp/voxtype-${VOXTYPE_VERSION}-mount"

  log "Downloading official Voxtype macOS release ${VOXTYPE_VERSION}..."
  rm -f "$dmg_path"
  curl -fL "$VOXTYPE_DMG_URL" -o "$dmg_path"

  rm -rf "$mount_dir"
  mkdir -p "$mount_dir"

  log "Mounting Voxtype DMG..."
  hdiutil attach "$dmg_path" -mountpoint "$mount_dir" -nobrowse -readonly >/dev/null
  trap 'hdiutil detach "$mount_dir" >/dev/null 2>&1 || true; rm -rf "$mount_dir"' EXIT

  mounted_bin="$mount_dir/voxtype"
  if [[ ! -x "$mounted_bin" ]]; then
    err "Voxtype binary was not found inside the DMG."
    exit 1
  fi

  log "Installing Voxtype binary to $VOXTYPE_BIN..."
  mkdir -p "$VOXTYPE_BIN_DIR"
  ditto "$mounted_bin" "$VOXTYPE_BIN"
  chmod 755 "$VOXTYPE_BIN"

  hdiutil detach "$mount_dir" >/dev/null
  trap - EXIT
  rm -rf "$mount_dir"
}

ensure_homebrew_formula() {
  local formula="$1"

  if brew list --formula "$formula" >/dev/null 2>&1; then
    return
  fi

  log "Installing Homebrew build dependency: ${formula}"
  brew install "$formula"
}

prepare_source_build_dependencies() {
  if command -v brew >/dev/null 2>&1; then
    ensure_homebrew_formula cmake
    ensure_homebrew_formula pkgconf
    ensure_homebrew_formula onnxruntime

    export PKG_CONFIG_PATH="$(brew --prefix onnxruntime)/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    export ORT_LIB_PATH="$(brew --prefix onnxruntime)/lib"
  fi

  require_command cargo
  require_command cmake
  require_command pkg-config

  if ! pkg-config --exists libonnxruntime; then
    err "Missing libonnxruntime pkg-config metadata. Install it with: brew install onnxruntime"
    exit 1
  fi
}

binary_features() {
  local voxtype_bin="$1"

  "$voxtype_bin" info variants 2>/dev/null | sed -n 's/^[[:space:]]*Features:[[:space:]]*//p'
}

binary_supports_cohere() {
  local voxtype_bin="$1"
  local features

  [[ -x "$voxtype_bin" ]] || return 1
  features="$(binary_features "$voxtype_bin")"
  [[ ",${features// /}," == *",cohere,"* ]]
}

install_cohere_capable_binary() {
  if [[ -x "$VOXTYPE_COHERE_BIN" ]] \
    && [[ "$("$VOXTYPE_COHERE_BIN" --version 2>/dev/null | awk '{print $2}')" == "$VOXTYPE_VERSION" ]]; then
    log "Voxtype ${VOXTYPE_VERSION} Cohere source build is already installed."
    return
  fi

  prepare_source_build_dependencies

  log "Building Voxtype ${VOXTYPE_VERSION} from source with features: ${VOXTYPE_SOURCE_FEATURES}"
  warn "Upstream Voxtype does not expose a macOS Metal/CoreML provider for the Cohere ONNX engine; Cohere runs on CPU on macOS."
  cargo install \
    --git "$VOXTYPE_SOURCE_URL" \
    --tag "v${VOXTYPE_VERSION}" \
    --locked \
    --features "$VOXTYPE_SOURCE_FEATURES" \
    --root "$VOXTYPE_COHERE_ROOT" \
    --force \
    voxtype

  if [[ ! -x "$VOXTYPE_COHERE_BIN" ]]; then
    err "The source build completed, but the installed binary was not found: $VOXTYPE_COHERE_BIN"
    exit 1
  fi
}

select_voxtype_bin() {
  install_cohere_capable_binary
  SELECTED_VOXTYPE_BIN="$VOXTYPE_COHERE_BIN"
}

link_cli() {
  local voxtype_bin="$1"

  mkdir -p "$(dirname "$VOXTYPE_LINK")"
  ln -sfn "$voxtype_bin" "$VOXTYPE_LINK"
  log "Linked: $VOXTYPE_LINK -> $voxtype_bin"
}

link_config() {
  if [[ ! -f "$CONFIG_SRC" ]]; then
    err "Config source not found: $CONFIG_SRC"
    exit 1
  fi

  mkdir -p "$(dirname "$CONFIG_DEST")"
  ln -sfn "$CONFIG_SRC" "$CONFIG_DEST"
  log "Linked: $CONFIG_DEST -> $CONFIG_SRC"
}

validate_config() {
  local voxtype_bin="$1"

  log "Validating Voxtype macOS Cohere config..."
  VOXTYPE_COHERE_MODEL_DIR="$MODEL_DIR" "$voxtype_bin" -c "$CONFIG_DEST" config >/dev/null
}

enforce_cohere_config() {
  local config_file="$CONFIG_DEST"

  if [[ ! -f "$config_file" ]]; then
    err "Config file not found: $config_file"
    exit 1
  fi

  if [[ -L "$config_file" ]]; then
    config_file="$(readlink "$config_file")"
  fi

  if grep -q '^engine = ' "$config_file"; then
    sed -i '' 's/^engine = .*/engine = "cohere"/' "$config_file"
  else
    printf 'engine = "cohere"\n%s' "$(cat "$config_file")" > "$config_file"
  fi
}

file_size_gt() {
  local file="$1" min_bytes="$2"
  local size

  [[ -f "$file" ]] || return 1
  size="$(stat -f %z "$file")"
  (( size > min_bytes ))
}

cohere_model_installed() {
  file_size_gt "$MODEL_DIR/encoder_model.onnx" 1024 \
    && file_size_gt "$MODEL_DIR/decoder_model_merged.onnx" 1024 \
    && file_size_gt "$MODEL_DIR/encoder_model_q4f16.onnx_data" 1048576 \
    && file_size_gt "$MODEL_DIR/decoder_model_merged_q4f16.onnx_data" 1048576 \
    && file_size_gt "$MODEL_DIR/tokenizer.json" 1048576 \
    && [[ -s "$MODEL_DIR/config.json" ]] \
    && [[ -s "$MODEL_DIR/generation_config.json" ]] \
    && [[ -s "$MODEL_DIR/processor_config.json" ]] \
    && [[ -s "$MODEL_DIR/tokenizer_config.json" ]]
}

download_cohere_file() {
  local src="$1" dest="$2"
  local tmp_file="$MODEL_DIR/${dest}.new"

  log "Downloading ${dest} from the official Cohere ONNX repo..."
  rm -f "$tmp_file"
  curl -fL "$COHERE_REPO/resolve/main/${src}" -o "$tmp_file"
  mv -f "$tmp_file" "$MODEL_DIR/${dest}"
}

install_cohere_model() {
  if cohere_model_installed; then
    log "Cohere model is already installed: ${COHERE_MODEL}"
    return
  fi

  if [[ -d "$LEGACY_MODEL_DIR" ]]; then
    mkdir -p "$MODEL_BASE_DIR"
    ln -sfn "$LEGACY_MODEL_DIR" "$MODEL_DIR"
    if cohere_model_installed; then
      log "Linked existing Cohere model into Voxtype's macOS model directory."
      return
    fi
  fi

  mkdir -p "$MODEL_DIR"

  download_cohere_file "onnx/encoder_model_q4f16.onnx" "encoder_model.onnx"
  download_cohere_file "onnx/encoder_model_q4f16.onnx_data" "encoder_model_q4f16.onnx_data"
  download_cohere_file "onnx/decoder_model_merged_q4f16.onnx" "decoder_model_merged.onnx"
  download_cohere_file "onnx/decoder_model_merged_q4f16.onnx_data" "decoder_model_merged_q4f16.onnx_data"
  download_cohere_file "tokenizer.json" "tokenizer.json"
  download_cohere_file "tokenizer_config.json" "tokenizer_config.json"
  download_cohere_file "config.json" "config.json"
  download_cohere_file "generation_config.json" "generation_config.json"
  download_cohere_file "processor_config.json" "processor_config.json"

  if ! cohere_model_installed; then
    err "Cohere model was not installed correctly."
    exit 1
  fi
}

run_setup_check() {
  local voxtype_bin="$1"

  log "Running Voxtype setup check..."
  VOXTYPE_COHERE_MODEL_DIR="$MODEL_DIR" "$voxtype_bin" -c "$CONFIG_DEST" setup check || {
    warn "Setup check reported an issue. macOS may still need Microphone, Accessibility, or Input Monitoring permission."
  }
}

install_app_bundle() {
  local voxtype_bin="$1"

  log "Creating or updating Voxtype.app from the installed binary..."
  VOXTYPE_COHERE_MODEL_DIR="$MODEL_DIR" "$voxtype_bin" -c "$CONFIG_DEST" setup app-bundle || {
    warn "Could not create Voxtype.app automatically."
    warn "Run 'voxtype setup app-bundle' manually if permissions do not attach to the app."
  }
}

install_launch_agent() {
  local voxtype_bin="$1"
  local voxtype_path_dir
  local uid

  uid="$(id -u)"
  voxtype_path_dir="$(dirname "$voxtype_bin")"
  mkdir -p "$(dirname "$LAUNCH_AGENT_PLIST")" "$LOG_DIR"

  log "Installing launch agent: $LAUNCH_AGENT_PLIST"
  cat > "$LAUNCH_AGENT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LAUNCH_AGENT_LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${voxtype_bin}</string>
    <string>-c</string>
    <string>${CONFIG_DEST}</string>
    <string>daemon</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${LOG_DIR}/launchd.out.log</string>
  <key>StandardErrorPath</key>
  <string>${LOG_DIR}/launchd.err.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>${voxtype_path_dir}:${HOME}/.local/bin:${HOME}/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>VOXTYPE_COHERE_MODEL_DIR</key>
    <string>${MODEL_DIR}</string>
  </dict>
</dict>
</plist>
PLIST

  plutil -lint "$LAUNCH_AGENT_PLIST" >/dev/null

  launchctl bootout "gui/${uid}" "$LAUNCH_AGENT_PLIST" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/${uid}" "$LAUNCH_AGENT_PLIST"
  launchctl enable "gui/${uid}/${LAUNCH_AGENT_LABEL}"
  launchctl kickstart -k "gui/${uid}/${LAUNCH_AGENT_LABEL}"
}

confirm_running() {
  local voxtype_bin="$1"
  local attempt status

  for attempt in 1 2 3 4 5; do
    sleep 1
    status="$(VOXTYPE_COHERE_MODEL_DIR="$MODEL_DIR" "$voxtype_bin" -c "$CONFIG_DEST" status 2>/dev/null || true)"
    if [[ "$status" != "stopped" && -n "$status" ]]; then
      log "Voxtype daemon status: $status"
      return 0
    fi
  done

  warn "Voxtype daemon did not report running yet. Check ${LOG_DIR}/launchd.err.log and macOS Accessibility/Input Monitoring permissions."
  return 1
}

main() {
  local voxtype_bin

  preflight
  remove_stale_homebrew_cask
  install_voxtype_binary

  select_voxtype_bin
  voxtype_bin="$SELECTED_VOXTYPE_BIN"

  link_cli "$voxtype_bin"
  link_config
  validate_config "$voxtype_bin"
  install_cohere_model
  run_setup_check "$voxtype_bin"
  install_app_bundle "$voxtype_bin"
  enforce_cohere_config
  validate_config "$voxtype_bin"
  install_launch_agent "$voxtype_bin"
  confirm_running "$voxtype_bin"

  log "Voxtype macOS Cohere install complete."
}

main "$@"
