#!/usr/bin/env bash
rc_vpn_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$rc_vpn_dir/settings"

rc_sshd_dropin=/etc/ssh/sshd_config.d/10-rc.conf
rc_sshd_settings='PasswordAuthentication no
KbdInteractiveAuthentication no
AuthenticationMethods publickey'

rc_sudo() {
  if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

rc_ip_number() {
  local a b c d
  IFS=. read -r a b c d <<<"$1"
  echo $(( (a << 24) | (b << 16) | (c << 8) | d ))
}

rc_in_network() {
  local bits=${2#*/} mask
  mask=$(( bits == 0 ? 0 : (0xFFFFFFFF << (32 - bits)) & 0xFFFFFFFF ))
  [[ $(( $(rc_ip_number "$1") & mask )) -eq $(( $(rc_ip_number "${2%/*}") & mask )) ]]
}

rc_address_in() {
  local network=$1 skip=${2:-} interface address
  while read -r interface address; do
    if [[ -n $skip && $interface == $skip ]]; then continue; fi
    if rc_in_network "$address" "$network"; then
      printf '%s %s\n' "$interface" "$address"
      return 0
    fi
  done < <(rc_addresses)
  return 1
}

rc_vpn_address() {
  local found
  found=$(rc_address_in "$RC_VPN_NETWORK") || return 1
  printf '%s\n' "${found#* }"
}

rc_write_root_file() {
  rc_changed=0
  if [[ "$(rc_sudo cat "$1" 2>/dev/null || true)" == "$2" ]]; then return 0; fi
  printf '%s\n' "$2" | rc_sudo tee "$1" >/dev/null
  rc_sudo chmod 644 "$1"
  rc_changed=1
}

rc_configure_sshd() {
  rc_sudo mkdir -p "$(dirname "$rc_sshd_dropin")"
  rc_write_root_file "$rc_sshd_dropin" "$rc_sshd_settings"
  rc_sudo sshd -t
}

rc_read_config() {
  local line text peer=0 started=0 config=''
  echo 'Paste the WireGuard config from add-client.sh, then press Enter on an empty line.' >&2
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%$'\r'}
    text=${line//[[:space:]]/}
    if [[ $started -eq 0 ]]; then
      if [[ $text != '[Interface]' ]]; then continue; fi
      started=1
    fi
    if [[ $peer -eq 1 && -z $text ]]; then break; fi
    if [[ $text == '[Peer]' ]]; then peer=1; fi
    config+="$line"$'\n'
  done
  if [[ $peer -eq 0 || $config != *PrivateKey* ]]; then
    echo 'That is not a WireGuard config from add-client.sh. Run this again and paste from [Interface] through PersistentKeepalive.' >&2
    return 1
  fi
  printf '%s' "$config"
}

rc_add_home_route() {
  awk -v home="$RC_VPN_HOME_NETWORK" '
!done && tolower($0) ~ /^[ \t]*allowedips[ \t]*=/ {
  done = 1
  sub(/[ \t]+$/, "")
  list = $0
  sub(/^[^=]*=[ \t]*/, "", list)
  n = split(list, routes, /[ \t]*,[ \t]*/)
  for (i = 1; i <= n; i++) if (routes[i] == "0.0.0.0/0" || routes[i] == home) { print; next }
  print $0 ", " home
  added = 1
  next
}
{ print }
END {
  if (!done) { print "The config has no AllowedIPs line. Paste the whole config from add-client.sh." > "/dev/stderr"; exit 1 }
  if (added) print "Also routing the home network " home " through the VPN." > "/dev/stderr"
}'
}
