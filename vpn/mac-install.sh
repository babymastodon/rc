#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

rc_app=/Applications/WireGuard.app
rc_app_store=https://apps.apple.com/app/wireguard/id1451685025
rc_pf_label=rc.vpn.pf
rc_pf_anchor=/etc/pf.anchors/$RC_VPN_TUNNEL
rc_pf_daemon=/Library/LaunchDaemons/$rc_pf_label.plist
rc_vpn_interface='utun*'

rc_addresses() {
  ifconfig | awk '/^[^ \t]/ { interface = $1; sub(/:$/, "", interface) } $1 == "inet" { print interface, $2 }'
}

rc_home_lan() {
  rc_address_in "$RC_VPN_HOME_NETWORK" "$rc_vpn_interface"
}

rc_computer_name() {
  scutil --get LocalHostName | tr '[:upper:]' '[:lower:]'
}

rc_add_to_agent() {
  ssh-add --apple-use-keychain "$1" >&2
  if ! grep -qiE '^[[:space:]]*UseKeychain[[:space:]]+yes' ~/.ssh/config 2>/dev/null; then
    printf '\nHost *\n    UseKeychain yes\n    AddKeysToAgent yes\n' >> ~/.ssh/config
  fi
}

rc_network_trust_warning() {
  :
}

rc_vpn_state() {
  scutil --nc list | awk -v name="\"$RC_VPN_TUNNEL\"" 'index($0, name) && match($0, /\([A-Za-z]+\)/) { print substr($0, RSTART + 1, RLENGTH - 2); exit }'
}

rc_pf_rules() {
  printf 'pass in quick proto tcp from %s to any port 22\n' "$RC_VPN_NETWORK" "$RC_VPN_HOME_NETWORK"
  printf 'block in quick proto tcp from any to any port 22\n'
}

rc_pf_plist() {
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$rc_pf_label</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/sh</string>
        <string>-c</string>
        <string>/sbin/pfctl -E -f /etc/pf.conf; /sbin/pfctl -a com.apple/$RC_VPN_TUNNEL -f $rc_pf_anchor</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
}

rc_configure_firewall() {
  rc_write_root_file "$rc_pf_anchor" "$(rc_pf_rules)"
  rc_write_root_file "$rc_pf_daemon" "$(rc_pf_plist)"
  rc_sudo launchctl bootout "system/$rc_pf_label" 2>/dev/null || true
  rc_sudo launchctl bootstrap system "$rc_pf_daemon"
}

rc_remote_login_on() {
  rc_sudo launchctl print system/com.openssh.sshd >/dev/null 2>&1
}

rc_enable_remote_login() {
  if rc_remote_login_on; then return 0; fi
  rc_sudo launchctl enable system/com.openssh.sshd
  if ! rc_sudo launchctl bootstrap system /System/Library/LaunchDaemons/ssh.plist; then
    echo 'Could not turn on Remote Login. Turn it on in System Settings > General > Sharing, then run this again.' >&2
    exit 1
  fi
}

rc_status() {
  local state address
  if [[ ! -d $rc_app ]]; then
    echo "WireGuard: not installed. Install it from the Mac App Store, then run vpn/mac-connect.sh: $rc_app_store"
  fi
  state=$(rc_vpn_state)
  if [[ -z $state ]]; then
    echo 'VPN: not enrolled yet. Run vpn/mac-connect.sh.'
  elif address=$(rc_vpn_address); then
    echo "VPN: $RC_VPN_TUNNEL is on at $address. Turn it on or off from the WireGuard menu bar icon."
  else
    echo "VPN: $RC_VPN_TUNNEL is $(printf '%s' "$state" | tr '[:upper:]' '[:lower:]'). Turn it on from the WireGuard menu bar icon."
  fi
  if rc_remote_login_on; then
    echo "SSH: Remote Login is on, key login only, from the VPN ($RC_VPN_NETWORK) and the home network ($RC_VPN_HOME_NETWORK). Blocked elsewhere."
  else
    echo 'SSH: Remote Login is off.'
  fi
}

rc_install() {
  rc_configure_firewall
  rc_configure_sshd
  rc_enable_remote_login
  rc_status
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then rc_install "$@"; fi
