#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VOXTYPE_REPO_API="https://api.github.com/repos/peteonrails/voxtype/releases"
DEFAULT_PACKAGE_VERSION="0.7.3"
DEFAULT_MODEL="${VOXTYPE_MODEL:-small.en}"
NEEDS_LOGOUT=0

log()   { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

need_sudo() { if [[ $EUID -ne 0 ]]; then echo "sudo"; fi; }
SUDO="$(need_sudo || true)"
TARGET_USER="${SUDO_USER:-${USER:-$(id -un)}}"

maybe_link() {
  local src="$1" dest="$2"

  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ -L "$dest" ]]; then
      local target
      target="$(readlink "$dest")"
      if [[ "$target" == "$src" ]]; then
        log "Link already correct: $dest -> $src"
      else
        warn "Link exists but wrong target ($target), fixing..."
        rm -f "$dest"
        ln -s "$src" "$dest"
        log "Fixed link: $dest -> $src"
      fi
    else
      warn "Exists and not a link: $dest (skipping)"
    fi
  else
    ln -s "$src" "$dest"
    log "Linked: $dest -> $src"
  fi
}

source_os_release() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
  fi
}

detect_pkg_type() {
  source_os_release

  case "${ID:-}" in
    ubuntu|debian)
      echo "deb"
      return
      ;;
    fedora|rhel|centos|rocky|almalinux)
      echo "rpm"
      return
      ;;
  esac

  if command -v apt-get >/dev/null 2>&1; then
    echo "deb"
  elif command -v dnf >/dev/null 2>&1; then
    echo "rpm"
  else
    echo ""
  fi
}

version_major() {
  local version_id="${VERSION_ID:-0}"
  printf '%s\n' "${version_id%%.*}"
}

check_supported_distro() {
  source_os_release
  local major
  major="$(version_major)"

  case "${ID:-}" in
    ubuntu)
      if (( major < 24 )); then
        err "Voxtype prebuilt packages require Ubuntu 24.04 or newer."
        exit 1
      fi
      ;;
    debian)
      if (( major < 13 )); then
        err "Voxtype prebuilt packages require Debian 13 (Trixie) or newer."
        exit 1
      fi
      ;;
    fedora)
      if (( major < 40 )); then
        err "Voxtype prebuilt packages require Fedora 40 or newer."
        exit 1
      fi
      ;;
    rhel|centos|rocky|almalinux)
      warn "Using the RPM package on ${PRETTY_NAME:-this distro}; upstream documents Fedora/RHEL-family support."
      ;;
  esac
}

ensure_arch() {
  case "$(uname -m)" in
    x86_64|amd64)
      ;;
    *)
      err "This prebuilt .deb/.rpm installer only supports x86_64 Linux."
      err "Upstream documents separate manual binaries for Linux arm64."
      exit 1
      ;;
  esac
}

install_pkgs() {
  local pkg_type="$1"
  shift

  ensure_sudo_auth

  case "$pkg_type" in
    deb)
      $SUDO apt-get update
      $SUDO apt-get install -y "$@"
      ;;
    rpm)
      $SUDO dnf install -y "$@"
      ;;
  esac
}

ensure_curl() {
  local pkg_type="$1"
  if command -v curl >/dev/null 2>&1; then
    return
  fi

  log "Installing curl..."
  install_pkgs "$pkg_type" curl
}

ensure_python3() {
  local pkg_type="$1"
  if command -v python3 >/dev/null 2>&1; then
    return
  fi

  log "Installing python3..."
  install_pkgs "$pkg_type" python3
}

ensure_sudo_auth() {
  if [[ -z "$SUDO" ]]; then
    return
  fi

  log "Checking sudo access..."
  $SUDO -v || {
    err "sudo authentication is required to install Voxtype packages and update group membership."
    exit 1
  }
}

package_installed() {
  local pkg_type="$1" pkg="$2"

  case "$pkg_type" in
    deb)
      dpkg -s "$pkg" >/dev/null 2>&1
      ;;
    rpm)
      rpm -q "$pkg" >/dev/null 2>&1
      ;;
  esac
}

package_pattern() {
  local pkg_type="$1"
  case "$pkg_type" in
    deb) printf '^voxtype_[0-9].*_amd64[.]deb$' ;;
    rpm) printf '^voxtype-[0-9].*[.]x86_64[.]rpm$' ;;
  esac
}

resolve_package_asset() {
  local pkg_type="$1"
  local requested="${VOXTYPE_VERSION:-latest-packaged}"
  local api_url pattern json

  pattern="$(package_pattern "$pkg_type")"
  if [[ "$requested" == "latest" || "$requested" == "latest-packaged" ]]; then
    api_url="${VOXTYPE_REPO_API}?per_page=20"
  else
    api_url="${VOXTYPE_REPO_API}/tags/v${requested#v}"
  fi

  json="$(curl -fsSL "$api_url")"
  python3 -c '
import json
import re
import sys

pattern = re.compile(sys.argv[1])
requested = sys.argv[2]
data = json.load(sys.stdin)
releases = data if isinstance(data, list) else [data]

for release in releases:
    tag = release.get("tag_name", "")
    version = tag.removeprefix("v")
    for asset in release.get("assets", []):
        name = asset.get("name", "")
        url = asset.get("browser_download_url", "")
        if pattern.match(name) and url:
            print(f"{version}\t{name}\t{url}")
            raise SystemExit(0)

if requested in {"latest", "latest-packaged"}:
    print("No recent Voxtype release publishes a matching .deb/.rpm asset.", file=sys.stderr)
else:
    print(f"Voxtype {requested} does not publish a matching .deb/.rpm asset.", file=sys.stderr)
raise SystemExit(1)
' "$pattern" "$requested" <<< "$json"
}

fallback_package_asset() {
  local pkg_type="$1" version="$DEFAULT_PACKAGE_VERSION" package_name url

  case "$pkg_type" in
    deb) package_name="voxtype_${version}-1_amd64.deb" ;;
    rpm) package_name="voxtype-${version}-1.x86_64.rpm" ;;
  esac

  url="https://github.com/peteonrails/voxtype/releases/download/v${version}/${package_name}"
  printf '%s\t%s\t%s\n' "$version" "$package_name" "$url"
}

install_runtime_deps() {
  local pkg_type="$1"
  local -a packages=() missing=()
  local pkg

  case "$pkg_type" in
    deb)
      packages=(ydotool wl-clipboard libnotify-bin playerctl pipewire-alsa libvulkan1)
      ;;
    rpm)
      packages=(ydotool wl-clipboard libnotify playerctl pipewire-alsa vulkan-loader)
      ;;
  esac

  for pkg in "${packages[@]}"; do
    package_installed "$pkg_type" "$pkg" || missing+=("$pkg")
  done

  if (( ${#missing[@]} == 0 )); then
    log "Recommended Voxtype runtime packages are already installed."
    return
  fi

  log "Installing missing Voxtype runtime packages: ${missing[*]}"
  install_pkgs "$pkg_type" "${missing[@]}" \
    || warn "Some recommended runtime packages could not be installed."
}

download_and_install_voxtype() {
  local pkg_type="$1" version="$2" package_name="$3" url="$4"
  local tmpdir package_path

  tmpdir="$(mktemp -d)"
  trap "rm -rf '$tmpdir'" EXIT

  package_path="${tmpdir}/${package_name}"

  log "Downloading Voxtype ${version} package..."
  curl -fL "$url" -o "$package_path"

  log "Installing ${package_name}..."
  case "$pkg_type" in
    deb)
      $SUDO apt-get install -y "$package_path"
      ;;
    rpm)
      $SUDO dnf install -y "$package_path"
      ;;
  esac
}

installed_voxtype_version() {
  if command -v voxtype >/dev/null 2>&1; then
    voxtype --version 2>/dev/null | awk '{print $2; exit}'
  fi
}

ensure_voxtype_package() {
  local pkg_type="$1" version="$2" package_name="$3" url="$4"
  local installed_version

  installed_version="$(installed_voxtype_version)"
  if [[ "$installed_version" == "$version" ]]; then
    log "Voxtype ${version} already installed."
    return
  fi

  download_and_install_voxtype "$pkg_type" "$version" "$package_name" "$url"
}

link_config() {
  mkdir -p "$HOME/.config/voxtype"
  maybe_link "$REPO_ROOT/voxtype/config.toml" "$HOME/.config/voxtype/config.toml"
}

enable_input_group() {
  if getent group input >/dev/null 2>&1; then
    if id -nG "$TARGET_USER" | tr ' ' '\n' | grep -qx input; then
      log "${TARGET_USER} is already in the input group."
      if ! id -nG | tr ' ' '\n' | grep -qx input; then
        NEEDS_LOGOUT=1
        warn "This login session has not picked up the input group yet; log out and back in before using the F23 hotkey."
      fi
      return
    fi

    log "Adding ${TARGET_USER} to input group for Voxtype evdev hotkey support..."
    $SUDO usermod -aG input "$TARGET_USER" || {
      warn "Could not add ${TARGET_USER} to input group."
      return
    }
    NEEDS_LOGOUT=1
  else
    warn "input group not found; Voxtype evdev hotkey support may need manual setup."
  fi
}

enable_user_service() {
  if ! command -v systemctl >/dev/null 2>&1; then
    warn "systemctl not found; start Voxtype manually with: voxtype daemon"
    return
  fi

  if (( NEEDS_LOGOUT )); then
    log "Enabling Voxtype user service for the next graphical login..."
    systemctl --user daemon-reload || true
    systemctl --user enable voxtype \
      || warn "Could not enable the Voxtype user service. Try after logout/login: systemctl --user enable --now voxtype"
    return
  fi

  log "Enabling and starting Voxtype user service..."
  systemctl --user daemon-reload || true
  systemctl --user enable --now voxtype \
    || warn "Could not enable the Voxtype user service. Try: systemctl --user enable --now voxtype"
}

enable_ydotool_service() {
  if ! command -v ydotool >/dev/null 2>&1; then
    warn "ydotool is not installed; GNOME typing output will fall back to clipboard."
    return
  fi

  if [[ -r /dev/uinput && -w /dev/uinput ]]; then
    local user_unit_dir="$HOME/.config/systemd/user"
    local user_unit="${user_unit_dir}/ydotool.service"

    if [[ -S /tmp/.ydotool_socket && ! -w /tmp/.ydotool_socket ]]; then
      warn "A root-owned ydotool socket is blocking the user ydotool service."
      if systemctl is-active --quiet ydotool 2>/dev/null; then
        log "Disabling root ydotool service so the user service can own the socket..."
        ensure_sudo_auth
        $SUDO systemctl disable --now ydotool \
          || warn "Could not disable root ydotool. Try: sudo systemctl disable --now ydotool"
      fi
      if [[ -S /tmp/.ydotool_socket && ! -w /tmp/.ydotool_socket ]]; then
        ensure_sudo_auth
        $SUDO rm -f /tmp/.ydotool_socket \
          || warn "Could not remove root-owned /tmp/.ydotool_socket."
      fi
    fi

    log "Installing ydotool user service for GNOME typing output..."
    mkdir -p "$user_unit_dir"
    cat > "$user_unit" <<'EOF'
[Unit]
Description=ydotool daemon for user-owned keyboard injection

[Service]
Type=simple
ExecStart=/usr/bin/ydotoold
Restart=on-failure

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload || true
    systemctl --user enable --now ydotool \
      || warn "Could not enable ydotool user service. Try: systemctl --user enable --now ydotool"
    return
  fi

  warn "Current user cannot access /dev/uinput; ydotool needs /dev/uinput access to type on GNOME."
}

validate_config() {
  if ! command -v voxtype >/dev/null 2>&1; then
    return
  fi

  log "Validating Voxtype config..."
  voxtype info variants >/dev/null || {
    err "Voxtype config validation failed: $HOME/.config/voxtype/config.toml"
    exit 1
  }
}

ensure_model() {
  local model="$1"

  if [[ "${VOXTYPE_DOWNLOAD_MODEL:-1}" != "1" ]]; then
    log "Skipping model download. To download later, run: voxtype setup --download --model ${model}"
    return
  fi

  log "Ensuring Voxtype model is installed: ${model}"
  voxtype setup --download --model "$model" --no-post-install || {
    warn "Voxtype model download failed. Rerun: voxtype setup --download --model ${model}"
    return
  }
}

run_setup_check() {
  log "Running Voxtype setup check..."
  voxtype setup check || {
    warn "Voxtype setup check reported issues. Review the output above."
    return
  }
}

print_next_steps() {
  if (( NEEDS_LOGOUT )); then
    warn "Log out and back in so this session can use the input group for the F23 push-to-talk hotkey."
  fi

  if ! systemctl --user is-active --quiet voxtype 2>/dev/null; then
    warn "Voxtype user service is not active in this shell. Try: systemctl --user enable --now voxtype"
  fi
}

pkg_type="$(detect_pkg_type)"
if [[ -z "$pkg_type" ]]; then
  err "No supported package manager detected. This installer supports apt-get and dnf."
  exit 1
fi

ensure_arch
check_supported_distro
ensure_curl "$pkg_type"
ensure_python3 "$pkg_type"

if ! package_info="$(resolve_package_asset "$pkg_type")"; then
  warn "Falling back to Voxtype ${DEFAULT_PACKAGE_VERSION}, the newest known packaged release."
  package_info="$(fallback_package_asset "$pkg_type")"
fi
IFS=$'\t' read -r version package_name package_url <<< "$package_info"

install_runtime_deps "$pkg_type"
ensure_voxtype_package "$pkg_type" "$version" "$package_name" "$package_url"
link_config
enable_ydotool_service
validate_config
enable_input_group
ensure_model "$DEFAULT_MODEL"
enable_user_service
run_setup_check
print_next_steps

log "Voxtype install complete."
