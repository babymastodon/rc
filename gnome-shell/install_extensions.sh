#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Configure extensions here (UUIDs)
#
# Put the configs in the <extension_name>.conf file.
# ============================================
EXTENSIONS=(
  "hidetopbar@mathieu.bidon.ca"
  "monitor-brightness-volume@ailin.nemui"
)

# --------------------------------------------
# GNOME Extensions installer
# Installs GNOME Extensions app + CLI if missing
# and installs listed extensions using major version only
# --------------------------------------------

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
      sudo apt-get update -y
      sudo apt-get install -y curl jq gnome-extensions gnome-extensions-app gnome-shell-extensions
      ;;
    fedora)
      sudo dnf install -y curl jq gnome-extensions gnome-extensions-app
      ;;
    arch)
      sudo pacman -Sy --noconfirm curl jq gnome-extensions gnome-extensions-app || true
      ;;
    opensuse*|sles)
      sudo zypper refresh
      sudo zypper install -y curl jq gnome-extensions gnome-extensions-app gnome-shell-extensions || true
      ;;
    *)
      echo "⚠️  Unknown distro. Please ensure curl, jq, gnome-extensions, and gnome-extensions-app are installed." >&2
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
    echo "→ Installing required GNOME tools..."
    install_pkgs
  fi
}

get_major_shell_version() {
  if ! require_cmd gnome-shell; then
    echo "⚠️  gnome-shell not found. Defaulting to 45." >&2
    echo "45"
    return 0
  fi
  local raw major
  raw="$(gnome-shell --version 2>/dev/null | awk '{print $3}')"
  major="${raw%%.*}"
  echo "$major"
}

install_extension_uuid() {
  local uuid="$1"
  local major="$2"
  local tmpdir="$(mktemp -d)"
  local info dl zip status

  echo "→ Resolving $uuid for GNOME Shell $major…"
  info="$(curl -fsSL "https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${major}" || true)"
  dl="$(jq -r '.download_url // empty' <<<"$info")"

  if [[ -z "$dl" || "$dl" == "null" ]]; then
    echo "❌  Could not find a compatible download for $uuid (shell $major). Skipping." >&2
    rm -rf "$tmpdir"
    return 1
  fi

  zip="$tmpdir/${uuid}.zip"
  curl -fsSL "https://extensions.gnome.org${dl}" -o "$zip"

  if gnome-extensions install --force "$zip"; then
    gnome-extensions enable "$uuid" || true
    echo "✅  $uuid installed and enabled (shell $major)."
  else
    echo "❌  $uuid failed to install."
  fi
  rm -rf "$tmpdir"
}

read_uuids_from_file() {
  local file="$1"
  [[ -f "$file" ]] || { echo "❌  File not found: $file" >&2; exit 1; }
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
      local conf_file="$prefix.conf"

      if [[ -f "$conf_file" ]]; then
          echo "→ Loading settings for $ext..."
          dconf load "$path" < "$conf_file"
          echo "✅  Successfully loaded settings for $ext."
      fi
  done
}

usage() {
  cat <<EOF
Usage:
  $0                       # install the EXTENSIONS array (top of script)
  $0 uuid1 uuid2 ...       # also install these extra UUIDs
  $0 -f extensions.txt     # also install from file (one UUID per line)

Notes:
- Uses only the MAJOR GNOME Shell version (e.g. 49 instead of 49.1)
- After installing, restart GNOME Shell or log out/in.
EOF
}

main() {
  local file=""
  local extra=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--file) file="$2"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) extra+=("$1"); shift ;;
    esac
  done

  ensure_base_tools
  local major
  major="$(get_major_shell_version)"
  echo "→ Detected GNOME Shell major version: $major"

  local all=("${EXTENSIONS[@]}")
  if [[ -n "$file" ]]; then
    mapfile -t file_uuids < <(read_uuids_from_file "$file")
    all+=("${file_uuids[@]}")
  fi
  all+=("${extra[@]}")
  mapfile -t all < <(printf "%s\n" "${all[@]}" | awk 'NF && !seen[$0]++')

  echo "→ Installing ${#all[@]} extension(s)…"
  for u in "${all[@]}"; do
    install_extension_uuid "$u" "$major"
  done

  load_gnome_extensions

  echo ""
  echo "✅  All done!"
  echo "- GNOME Extensions app + CLI installed if missing."
  echo "- Installed/Enabled extensions listed above."
  echo ""
  echo "You may need to restart GNOME Shell or log out/in for everything to take effect."
}

main "$@"

