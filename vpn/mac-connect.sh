#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/mac-install.sh"

rc_xml_escape() {
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

rc_profile() {
  local config endpoint
  config=$(printf '%s\n' "$1" | rc_xml_escape)
  endpoint=$(printf '%s\n' "$1" | awk -F= 'tolower($1) ~ /^[ \t]*endpoint[ \t]*$/ { gsub(/[ \t]/, "", $2); print $2; exit }' | rc_xml_escape)
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadDisplayName</key>
    <string>$RC_VPN_TUNNEL</string>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
    <key>PayloadIdentifier</key>
    <string>rc.vpn.$RC_VPN_TUNNEL</string>
    <key>PayloadUUID</key>
    <string>$(uuidgen)</string>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>PayloadDisplayName</key>
            <string>VPN</string>
            <key>PayloadType</key>
            <string>com.apple.vpn.managed</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadIdentifier</key>
            <string>rc.vpn.$RC_VPN_TUNNEL.tunnel</string>
            <key>PayloadUUID</key>
            <string>$(uuidgen)</string>
            <key>UserDefinedName</key>
            <string>$RC_VPN_TUNNEL</string>
            <key>VPNType</key>
            <string>VPN</string>
            <key>VPNSubType</key>
            <string>com.wireguard.macos</string>
            <key>VendorConfig</key>
            <dict>
                <key>WgQuickConfig</key>
                <string>$config</string>
            </dict>
            <key>VPN</key>
            <dict>
                <key>RemoteAddress</key>
                <string>$endpoint</string>
                <key>AuthenticationMethod</key>
                <string>Password</string>
            </dict>
        </dict>
    </array>
</dict>
</plist>
EOF
}

rc_connect() {
  local config profile
  if [[ ! -d $rc_app ]]; then
    echo "Install WireGuard from the Mac App Store first: $rc_app_store" >&2
    exit 1
  fi
  config=$(rc_read_config)
  config=$(printf '%s\n' "$config" | rc_add_home_route)
  rc_connect_dir=$(mktemp -d)
  trap 'rm -rf "$rc_connect_dir"' EXIT
  profile="$rc_connect_dir/$RC_VPN_TUNNEL.mobileconfig"
  rc_profile "$config" > "$profile"
  open "$profile"
  echo "Install the profile: in System Settings > General > Device Management (Privacy & Security > Profiles on older macOS), double-click $RC_VPN_TUNNEL and click Install."
  read -r -p 'Press Enter after installing it. ' _ </dev/tty
  rm -rf "$rc_connect_dir"
  if [[ -z $(rc_vpn_state) ]]; then
    echo "The $RC_VPN_TUNNEL profile is not installed. Run this again." >&2
    exit 1
  fi
  open -a WireGuard
  scutil --nc start "$RC_VPN_TUNNEL"
  for _ in $(seq 1 30); do
    if rc_vpn_address >/dev/null; then break; fi
    sleep 1
  done
  rc_status
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then rc_connect "$@"; fi
