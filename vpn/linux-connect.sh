#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/linux-install.sh"

rc_connect() {
  local config file
  if ! systemctl is-active --quiet NetworkManager; then
    echo 'NetworkManager is not running. Run vpn/linux-install.sh first.' >&2
    exit 1
  fi
  config=$(rc_read_config)
  config=$(printf '%s\n' "$config" | rc_add_home_route)
  rc_connect_dir=$(mktemp -d)
  trap 'rm -rf "$rc_connect_dir"' EXIT
  file="$rc_connect_dir/$RC_VPN_TUNNEL.conf"
  printf '%s\n' "$config" > "$file"
  if rc_vpn_enrolled; then rc_sudo nmcli connection delete "$RC_VPN_TUNNEL" >/dev/null; fi
  rc_sudo nmcli connection import type wireguard file "$file" >/dev/null
  rm -rf "$rc_connect_dir"
  rc_sudo nmcli connection modify "$RC_VPN_TUNNEL" connection.zone "$rc_trusted_zone" connection.autoconnect yes
  rc_sudo nmcli connection up "$RC_VPN_TUNNEL" >/dev/null
  rc_status
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then rc_connect "$@"; fi
