#!/usr/bin/env bash
# add-client.sh
# - Generates a new WireGuard client keypair
# - Prompts for VPN hostname and client name
# - Allocates the next free IP in the server /24 subnet
# - Renders a client config from example.conf, prints it and a QR code
# - Appends the new peer to the server config and reloads WireGuard
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "This script must be run as sudo/root." >&2
  exit 1
fi

wg_conf_path="$(ls /etc/wireguard/*.conf 2>/dev/null | head -n1 || true)"
if [[ -z "${wg_conf_path}" ]]; then
  echo "No WireGuard config found in /etc/wireguard/." >&2
  exit 1
fi

wg_conf_file="$(basename "${wg_conf_path}")"
wg_iface="${wg_conf_file%.conf}"

read -r -p "VPN hostname (example.com or x.x.x.x): " vpn_hostname
if [[ -z "${vpn_hostname}" ]]; then
  echo "Hostname is required." >&2
  exit 1
fi

read -r -p "New client name: " client_name
if [[ -z "${client_name}" ]]; then
  echo "Client name is required." >&2
  exit 1
fi

server_address_line="$(awk -F'=' '/^\s*Address\s*=/{print $2; exit}' "${wg_conf_path}" | tr -d '[:space:]')"
if [[ -z "${server_address_line}" ]]; then
  echo "Unable to find Interface Address in ${wg_conf_path}." >&2
  exit 1
fi

server_ip="${server_address_line%%/*}"
prefix_len="${server_address_line##*/}"
if [[ "${prefix_len}" != "24" ]]; then
  echo "This script currently expects a /24 subnet; found /${prefix_len}." >&2
  exit 1
fi

IFS='.' read -r o1 o2 o3 o4 <<< "${server_ip}"
if [[ -z "${o1}" || -z "${o2}" || -z "${o3}" || -z "${o4}" ]]; then
  echo "Invalid server IP address: ${server_ip}" >&2
  exit 1
fi

declare -A used_ips=()
used_ips["${server_ip}"]=1

while IFS= read -r ip; do
  ip="${ip%%/*}"
  [[ -n "${ip}" ]] && used_ips["${ip}"]=1
done < <(awk -F'=' '/^\s*AllowedIPs\s*=/{print $2}' "${wg_conf_path}" | tr -d '[:space:]')

new_ip=""
for last in $(seq 2 254); do
  candidate="${o1}.${o2}.${o3}.${last}"
  if [[ -z "${used_ips[${candidate}]+x}" ]]; then
    new_ip="${candidate}"
    break
  fi
done

if [[ -z "${new_ip}" ]]; then
  echo "No available IPs left in ${o1}.${o2}.${o3}.0/24." >&2
  exit 1
fi

client_private_key="$(wg genkey)"
client_public_key="$(printf '%s' "${client_private_key}" | wg pubkey)"

server_private_key="$(awk -F'=' '/^\s*PrivateKey\s*=/{print $2; exit}' "${wg_conf_path}" | tr -d '[:space:]')"
if [[ -z "${server_private_key}" ]]; then
  echo "Unable to find server PrivateKey in ${wg_conf_path}." >&2
  exit 1
fi
server_public_key="$(printf '%s' "${server_private_key}" | wg pubkey)"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
template_path="${script_dir}/example.conf"
if [[ ! -f "${template_path}" ]]; then
  echo "Template not found at ${template_path}." >&2
  exit 1
fi

client_config="$(
  sed \
    -e "s/CLIENT_PRIVATE_KEY/${client_private_key}/" \
    -e "s/ADDRESS/${new_ip}/" \
    -e "s/SERVER_PUBLIC_KEY/${server_public_key}/" \
    -e "s/HOSTNAME/${vpn_hostname}/" \
    "${template_path}"
)"

printf '%s\n' "Generated client config:"
printf '%s\n' "${client_config}"

printf '\n%s\n' "QR code:"
printf '%s' "${client_config}" | qrencode -t ansiutf8
printf '\n'

{
  printf '\n[Peer]\n'
  printf '# %s\n' "${client_name}"
  printf 'PublicKey = %s\n' "${client_public_key}"
  printf 'AllowedIPs = %s/32\n' "${new_ip}"
} >> "${wg_conf_path}"

wg syncconf "${wg_iface}" <(wg-quick strip "${wg_iface}")

printf 'Added %s with %s to %s and reloaded %s.\n' "${client_name}" "${new_ip}" "${wg_conf_path}" "${wg_iface}"
