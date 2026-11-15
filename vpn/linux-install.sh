#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

rc_trusted_zone=home
rc_vpn_interface=$RC_VPN_TUNNEL

rc_addresses() {
  ip -4 -o addr show | awk '{ split($4, address, "/"); print $2, address[1] }'
}

rc_home_lan() {
  rc_address_in "$RC_VPN_HOME_NETWORK" "$rc_vpn_interface"
}

rc_vpn_address() {
  ip -4 -o addr show dev "$rc_vpn_interface" 2>/dev/null |
    awk '{ split($4, address, "/"); print address[1]; found = 1; exit } END { exit !found }'
}

rc_computer_name() {
  local name
  name=$(uname -n)
  printf '%s\n' "${name%%.*}" | tr '[:upper:]' '[:lower:]'
}

rc_add_to_agent() {
  if [[ -n ${SSH_AUTH_SOCK:-} ]]; then
    ssh-add "$1" >&2
  else
    echo 'No ssh-agent is running, so ssh will ask for the passphrase when it needs the key.' >&2
  fi
}

rc_vpn_enrolled() {
  local names
  names=$(nmcli -g NAME connection show)
  grep -qxF "$RC_VPN_TUNNEL" <<<"$names"
}

rc_network_trust_warning() {
  local connection zone
  connection=$(nmcli -g GENERAL.CONNECTION device show "$1" 2>/dev/null || true)
  if [[ -z $connection ]]; then return 0; fi
  zone=$(nmcli -g connection.zone connection show "$connection" 2>/dev/null || true)
  if [[ -z $zone ]]; then zone=$(firewall-cmd --get-default-zone 2>/dev/null || true); fi
  if [[ $zone != "$rc_trusted_zone" ]]; then
    echo "The firewall puts '$connection' in zone '${zone:-unknown}', so it blocks SSH from $2. If it is your home network, trust it with: sudo nmcli connection modify '$connection' connection.zone $rc_trusted_zone, then reconnect to it." >&2
  fi
}

rc_install_fedora_packages() {
  local -a missing=()
  local package
  for package in NetworkManager firewalld openssh-server; do
    if ! rpm -q "$package" >/dev/null 2>&1; then missing+=("$package"); fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then rc_sudo dnf install -y "${missing[@]}"; fi
}

rc_configure_firewall() {
  local default
  rc_sudo systemctl enable --now firewalld
  default=$(rc_sudo firewall-cmd --get-default-zone)
  if [[ $default == "$rc_trusted_zone" ]]; then
    rc_sudo firewall-cmd --set-default-zone=public >/dev/null
    default=public
  fi
  if ! rc_sudo firewall-cmd --permanent --zone="$rc_trusted_zone" --query-service=ssh >/dev/null; then
    rc_sudo firewall-cmd --permanent --zone="$rc_trusted_zone" --add-service=ssh >/dev/null
  fi
  if rc_sudo firewall-cmd --permanent --zone="$default" --query-service=ssh >/dev/null; then
    rc_sudo firewall-cmd --permanent --zone="$default" --remove-service=ssh >/dev/null
  fi
  rc_sudo firewall-cmd --reload >/dev/null
}

rc_trust_vpn() {
  if ! rc_vpn_enrolled; then return 0; fi
  if [[ $(nmcli -g connection.zone connection show "$RC_VPN_TUNNEL") != "$rc_trusted_zone" ]]; then
    rc_sudo nmcli connection modify "$RC_VPN_TUNNEL" connection.zone "$rc_trusted_zone"
    if rc_vpn_address >/dev/null; then rc_sudo nmcli connection up "$RC_VPN_TUNNEL" >/dev/null; fi
  fi
}

rc_status() {
  local address routes zone
  if address=$(rc_vpn_address); then
    zone=$(nmcli -g connection.zone connection show "$RC_VPN_TUNNEL" 2>/dev/null || true)
    if [[ -z $zone ]]; then zone="$(firewall-cmd --get-default-zone 2>/dev/null || true), the default"; fi
    echo "VPN: $RC_VPN_TUNNEL is on at $address (firewall zone $zone). Turn it on or off from VPN in GNOME's Quick Settings menu."
    routes=$(ip -4 route show table all dev "$RC_VPN_TUNNEL" |
      awk '$1 != "local" && $1 != "broadcast" && $1 != "multicast" { print ($1 == "default" ? "0.0.0.0/0" : $1) }' |
      sort -u | paste -sd, - | sed 's/,/, /g')
    echo "VPN routes: $routes"
    case ", $routes," in
      *", $RC_VPN_HOME_NETWORK,"* | *", 0.0.0.0/0,"*) ;;
      *) echo "The home network $RC_VPN_HOME_NETWORK is not routed through the VPN. Re-enroll with vpn/linux-connect.sh to add it." ;;
    esac
  elif rc_vpn_enrolled; then
    echo "VPN: $RC_VPN_TUNNEL is off. Turn it on from VPN in GNOME's Quick Settings menu."
  else
    echo 'VPN: not enrolled yet. Run vpn/linux-connect.sh.'
  fi
  echo "SSH: $(systemctl is-active sshd || true), key login only, on the VPN and networks in firewall zone $rc_trusted_zone. Blocked elsewhere."
}

rc_install() {
  rc_install_fedora_packages
  rc_configure_firewall
  rc_configure_sshd
  rc_sudo systemctl enable --now sshd
  if [[ $rc_changed -eq 1 ]]; then rc_sudo systemctl restart sshd; fi
  rc_trust_vpn
  rc_status
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then rc_install "$@"; fi
