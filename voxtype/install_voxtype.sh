#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

VOXTYPE_VERSION="0.7.4"
COHERE_MODEL="cohere-transcribe-q4f16"
COHERE_REPO="https://huggingface.co/onnx-community/cohere-transcribe-03-2026-ONNX"

VOXTYPE_BIN_DIR="$HOME/.local/share/voxtype/bin"
VOXTYPE_BIN="$VOXTYPE_BIN_DIR/voxtype-onnx-avx2"
VOXTYPE_LINK="$HOME/.local/bin/voxtype"
VOXTYPE_URL="https://github.com/peteonrails/voxtype/releases/download/v${VOXTYPE_VERSION}/voxtype-${VOXTYPE_VERSION}-linux-x86_64-onnx-avx2"

CONFIG_SRC="$REPO_ROOT/voxtype/config.toml"
CONFIG_DEST="$HOME/.config/voxtype/config.toml"
MODEL_DIR="$HOME/.local/share/voxtype/models/${COHERE_MODEL}"

log() { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

require_command() {
  local cmd="$1"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    err "Missing required command: ${cmd}"
    exit 1
  fi
}

pkg_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    echo apt
  elif command -v dnf >/dev/null 2>&1; then
    echo dnf
  else
    err "Missing apt-get or dnf for system dependency installation."
    exit 1
  fi
}

package_installed() {
  local manager="$1" pkg="$2"

  case "$manager" in
    apt) dpkg -s "$pkg" >/dev/null 2>&1 ;;
    dnf) rpm -q "$pkg" >/dev/null 2>&1 ;;
  esac
}

install_system_deps() {
  local manager
  local -a packages missing
  local pkg

  manager="$(pkg_manager)"
  packages=(curl ydotool pipewire-alsa)
  missing=()

  for pkg in "${packages[@]}"; do
    package_installed "$manager" "$pkg" || missing+=("$pkg")
  done

  if (( ${#missing[@]} == 0 )); then
    log "Required system packages are already installed."
    return
  fi

  log "Installing missing system packages: ${missing[*]}"
  sudo -v

  case "$manager" in
    apt)
      sudo apt-get update
      sudo apt-get install -y "${missing[@]}"
      ;;
    dnf)
      sudo dnf install -y "${missing[@]}"
      ;;
  esac
}

preflight() {
  case "$(uname -m)" in
    x86_64|amd64) ;;
    *)
      err "This installer only supports x86_64 Linux."
      exit 1
      ;;
  esac

  pkg_manager >/dev/null

  if ! id -nG | tr ' ' '\n' | grep -qx input; then
    err "This login session is not in the input group."
    err "Fix once with: sudo usermod -aG input \$USER"
    err "Then log out and back in before rerunning this script."
    exit 1
  fi

  if [[ ! -r /dev/uinput || ! -w /dev/uinput ]]; then
    err "Current user cannot access /dev/uinput; ydotool cannot type on GNOME."
    exit 1
  fi
}

require_prereqs() {
  require_command curl
  require_command systemctl
  require_command ydotool
  require_command ydotoold
}

install_voxtype_binary() {
  local tmp_bin="${VOXTYPE_BIN}.new"

  mkdir -p "$VOXTYPE_BIN_DIR" "$HOME/.local/bin"

  log "Downloading official Voxtype ONNX CPU binary ${VOXTYPE_VERSION}..."
  rm -f "$tmp_bin"
  curl -fL "$VOXTYPE_URL" -o "$tmp_bin"
  chmod +x "$tmp_bin"
  mv -f "$tmp_bin" "$VOXTYPE_BIN"

  ln -sfnT "$VOXTYPE_BIN" "$VOXTYPE_LINK"
  log "Linked: $VOXTYPE_LINK -> $VOXTYPE_BIN"
}

link_config() {
  mkdir -p "$(dirname "$CONFIG_DEST")"
  ln -sfnT "$CONFIG_SRC" "$CONFIG_DEST"
  log "Linked: $CONFIG_DEST -> $CONFIG_SRC"
}

install_ydotool_user_service() {
  local service_file="$HOME/.config/systemd/user/ydotool.service"
  local ydotoold_bin

  ydotoold_bin="$(command -v ydotoold)"

  mkdir -p "$(dirname "$service_file")"
  cat > "$service_file" <<EOF
[Unit]
Description=ydotool daemon for user-owned keyboard injection

[Service]
Type=simple
ExecStart=$ydotoold_bin
Restart=on-failure

[Install]
WantedBy=default.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now ydotool
  log "Installed ydotool user service."
}

install_voxtype_user_service() {
  local service_file="$HOME/.config/systemd/user/voxtype.service"

  mkdir -p "$(dirname "$service_file")"
  cat > "$service_file" <<EOF
[Unit]
Description=Voxtype Cohere CPU daemon
After=graphical-session.target pipewire.service pipewire-pulse.service
Wants=ydotool.service

[Service]
Type=simple
ExecStart=$VOXTYPE_BIN -q daemon
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical-session.target
EOF

  systemctl --user daemon-reload
  log "Installed Voxtype user service."
}

file_size_gt() {
  local file="$1" min_bytes="$2"

  [[ -f "$file" ]] && (( "$(stat -c %s "$file")" > min_bytes ))
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

validate_config() {
  log "Validating Voxtype Cohere config..."
  "$VOXTYPE_BIN" config >/dev/null
}

start_voxtype_service() {
  systemctl --user enable --now voxtype
  systemctl --user restart voxtype
  log "Voxtype user service is running."
}

run_setup_check() {
  log "Running Voxtype setup check..."
  "$VOXTYPE_BIN" setup check
}

preflight
install_system_deps
require_prereqs
install_voxtype_binary
link_config
install_ydotool_user_service
install_voxtype_user_service
install_cohere_model
validate_config
start_voxtype_service
run_setup_check

log "Voxtype Cohere CPU install complete."
