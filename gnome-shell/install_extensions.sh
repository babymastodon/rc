#!/usr/bin/env bash
set -euo pipefail

# ----- helpers -----
log()   { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }
need_sudo() { if [[ $EUID -ne 0 ]]; then echo "sudo"; fi; }
SUDO="$(need_sudo || true)"

# ============================================
# Configure extensions here (UUIDs)
# ============================================
EXTENSIONS=(
  "hidetopbar@mathieu.bidon.ca"
  "monitor-brightness-volume@ailin.nemui"
  "azwallpaper@azwallpaper.gitlab.com"
  "blur-my-shell@aunetx"
)

# ----- helpers -----
require_cmd() { command -v "$1" &>/dev/null; }

detect_distro() {
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    echo "${ID:-unknown}"
  else
    echo "unknown"
  fi
}

install_pkgs() {
  local distro; distro="$(detect_distro)"
  case "$distro" in
    ubuntu|debian)
      log "Installing required packages (apt)"
      $SUDO apt-get update -y
      $SUDO apt-get install -y curl jq gnome-extensions gnome-extensions-app gnome-shell-extensions
      ;;
    fedora)
      log "Installing required packages (dnf)"
      $SUDO dnf install -y curl jq gnome-extensions gnome-extensions-app
      ;;
    arch)
      log "Installing required packages (pacman)"
      $SUDO pacman -Sy --noconfirm curl jq gnome-extensions gnome-extensions-app || true
      ;;
    opensuse*|sles)
      log "Installing required packages (zypper)"
      $SUDO zypper refresh
      $SUDO zypper install -y curl jq gnome-extensions gnome-extensions-app gnome-shell-extensions || true
      ;;
    *)
      warn "Unknown distro — please ensure curl, jq, gnome-extensions, and gnome-extensions-app are installed."
      ;;
  esac
}

ensure_base_tools() {
  local need_install=false
  for bin in curl jq gnome-extensions; do
    if ! require_cmd "$bin"; then need_install=true; fi
  done
  if ! require_cmd gnome-extensions-app; then need_install=true; fi

  if [[ "$need_install" == true ]]; then
    log "Installing missing GNOME tools..."
    install_pkgs
  else
    log "All required GNOME tools already installed."
  fi
}

get_major_shell_version() {
  if ! require_cmd gnome-shell; then
    warn "gnome-shell not found, defaulting to 45."
    echo "45"
    return 0
  fi
  local raw major
  raw="$(gnome-shell --version 2>/dev/null | awk '{print $3}')"
  major="${raw%%.*}"
  echo "$major"
}

find_extension_dir() {
  local uuid="$1"
  local dir

  for dir in \
    "$HOME/.local/share/gnome-shell/extensions/$uuid" \
    "/usr/local/share/gnome-shell/extensions/$uuid" \
    "/usr/share/gnome-shell/extensions/$uuid"
  do
    if [[ -d "$dir" ]]; then
      echo "$dir"
      return 0
    fi
  done

  return 1
}

print_extension_status() {
  local uuid="$1"
  local installed="no"
  local enabled="no"
  local version="unknown"
  local dir=""

  if gnome-extensions info "$uuid" &>/dev/null; then
    installed="yes"
    if gnome-extensions list --enabled | grep -Fxq "$uuid"; then
      enabled="yes"
    fi
  fi

  if dir="$(find_extension_dir "$uuid")"; then
    version="$(jq -r '.version // "unknown"' "$dir/metadata.json" 2>/dev/null || echo "unknown")"
  fi

  printf "%-40s installed=%-3s enabled=%-3s version=%s\n" "$uuid" "$installed" "$enabled" "$version"
}

install_extension_uuid() {
  local uuid="$1"
  local major="$2"
  local upgrade="${3:-false}"
  local tmpdir; tmpdir="$(mktemp -d)"
  local info dl zip

  if [[ "$upgrade" != true ]] && gnome-extensions info "$uuid" &>/dev/null; then
    log "Extension already installed: $uuid"
  else
    if gnome-extensions info "$uuid" &>/dev/null; then
      log "Upgrading $uuid for GNOME Shell $major"
    else
      log "Fetching $uuid for GNOME Shell $major"
    fi
    info="$(curl -fsSL "https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${major}" || true)"
    dl="$(jq -r '.download_url // empty' <<<"$info")"
    if [[ -z "$dl" || "$dl" == "null" ]]; then
      err "No compatible download for $uuid (shell $major)"
      rm -rf "$tmpdir"
      return 1
    fi

    zip="$tmpdir/${uuid}.zip"
    curl -fsSL "https://extensions.gnome.org${dl}" -o "$zip"
    gnome-extensions install --force "$zip" && log "Installed: $uuid" || err "Failed to install: $uuid"
  fi

  if gnome-extensions list --enabled | grep -Fxq "$uuid"; then
    log "Extension already enabled: $uuid"
  else
    gnome-extensions enable "$uuid" && log "Enabled extension: $uuid" || warn "Failed to enable extension: $uuid"
  fi

  rm -rf "$tmpdir"
}

read_uuids_from_file() {
  local file="$1"
  [[ -f "$file" ]] || { err "File not found: $file"; exit 1; }
  grep -v '^\s*$' "$file" | grep -v '^\s*#' | sed 's/^\s*//; s/\s*$//'
}

_get_dconf_key_prefix() {
  local uuid="$1"
  echo "$uuid" | cut -d'@' -f1
}

load_gnome_extensions() {
  for ext in "${EXTENSIONS[@]}"; do
    local prefix="$(_get_dconf_key_prefix "$ext")"
    local path="/org/gnome/shell/extensions/${prefix}/"
    local conf_file="${prefix}.conf"

    if [[ -f "$conf_file" ]]; then
      local current desired
      current="$(dconf dump "$path" 2>/dev/null || true)"
      desired="$(cat "$conf_file")"
      if [[ "$current" == "$desired" ]]; then
        log "Settings already up to date for $ext ($conf_file)"
      else
        log "Loading settings for $ext ($conf_file)"
        dconf load "$path" < "$conf_file"
        log "Applied settings for $ext"
      fi
    else
      log "No config found for: $ext (skipping)"
    fi
  done
}

set_gnome_input_prefs() {
  log "Applying GNOME input/interface preferences"

  # Allow extensions built for nearby GNOME Shell versions to load.
  local current_validation
  current_validation="$(gsettings get org.gnome.shell disable-extension-version-validation)"
  if [[ "$current_validation" != "true" ]]; then
    gsettings set org.gnome.shell disable-extension-version-validation true
    log "Disabled extension version validation (was $current_validation)"
  else
    log "Extension version validation already disabled"
  fi

  # Disable hot corner
  local current_hot
  current_hot="$(gsettings get org.gnome.desktop.interface enable-hot-corners)"
  if [[ "$current_hot" != "false" ]]; then
    gsettings set org.gnome.desktop.interface enable-hot-corners false
    log "Disabled hot corners (was $current_hot)"
  else
    log "Hot corners already disabled"
  fi

  # Trackpad scrolling
  local current_nat
  current_nat="$(gsettings get org.gnome.desktop.peripherals.touchpad natural-scroll)"
  if [[ "$current_nat" != "false" ]]; then
    gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll false
    log "Set traditional scroll direction (was $current_nat)"
  else
    log "Trackpad already traditional scroll"
  fi
}

usage() {
  cat <<EOF
Usage:
  $0                       # install the EXTENSIONS array
  $0 --status             # print installed/enabled/version for the EXTENSIONS array
  $0 --upgrade            # upgrade installed extensions in the EXTENSIONS array
  $0 --status uuid1 ...   # print status for the listed UUIDs too
  $0 uuid1 uuid2 ...       # install extra UUIDs
  $0 --upgrade uuid1 ...   # upgrade/install the listed UUIDs too
  $0 -f extensions.txt     # install from file (one UUID per line)
EOF
}

main() {
  local file=""
  local extra=()
  local status=false
  local upgrade=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--file) file="$2"; shift 2 ;;
      -s|--status) status=true; shift ;;
      -u|--upgrade) upgrade=true; shift ;;
      -h|--help) usage; exit 0 ;;
      *) extra+=("$1"); shift ;;
    esac
  done

  ensure_base_tools
  local major; major="$(get_major_shell_version)"
  log "Detected GNOME Shell major version: $major"

  local all=("${EXTENSIONS[@]}")
  if [[ -n "$file" ]]; then
    mapfile -t file_uuids < <(read_uuids_from_file "$file")
    all+=("${file_uuids[@]}")
  fi
  all+=("${extra[@]}")
  mapfile -t all < <(printf "%s\n" "${all[@]}" | awk 'NF && !seen[$0]++')

  if [[ "$status" == true ]]; then
    log "Extension status for ${#all[@]} extension(s)"
    for u in "${all[@]}"; do
      print_extension_status "$u"
    done
    exit 0
  fi

  if [[ "$upgrade" == true ]]; then
    log "Installing/upgrading ${#all[@]} extension(s)"
  else
    log "Installing ${#all[@]} extension(s)"
  fi
  for u in "${all[@]}"; do
    install_extension_uuid "$u" "$major" "$upgrade"
  done

  load_gnome_extensions
  set_gnome_input_prefs

  echo ""
  log "All done!"
  warn "Restart GNOME Shell (Alt+F2 → 'r') or log out/in for changes to apply."
}

main "$@"
