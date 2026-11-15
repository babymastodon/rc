#!/usr/bin/env bash
set -euo pipefail
rc_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "$(uname -s)" in
  Darwin) . "$rc_here/mac-install.sh" ;;
  Linux) . "$rc_here/linux-install.sh" ;;
  *) echo "Unsupported system: $(uname -s)" >&2; exit 1 ;;
esac

rc_keys_file=~/.ssh/authorized_keys
rc_key_pattern='^(ssh-|ecdsa-|sk-)[A-Za-z0-9@._-]+$'
rc_blob_pattern='^[A-Za-z0-9+/]+=*$'
rc_name_pattern='^[a-z0-9][a-z0-9-]*$'
rc_user_pattern='^[A-Za-z0-9_.-]+$'
rc_target_pattern='^([A-Za-z0-9_][A-Za-z0-9_.-]*@)?[A-Za-z0-9_][A-Za-z0-9_.-]*$'

rc_identity() {
  rc_name=$(rc_computer_name)
  rc_user=$(id -un)
  if [[ ! $rc_name =~ $rc_name_pattern || ! $rc_user =~ $rc_user_pattern ]]; then
    echo "Rename this computer or account to use only letters, digits and hyphens: $rc_name, $rc_user." >&2
    exit 1
  fi
}

rc_own_key() {
  local key=~/.ssh/id_ed25519
  if [[ ! -f $key ]]; then
    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    echo 'Creating an SSH key for this computer. Choose a passphrase for it.' >&2
    ssh-keygen -q -t ed25519 -a 100 -C "$rc_user@$rc_name" -f "$key"
    rc_add_to_agent "$key"
  fi
  read -r rc_key_type rc_key_blob _ < "$key.pub"
  if [[ ! $rc_key_type =~ $rc_key_pattern || ! ${rc_key_blob:-} =~ $rc_blob_pattern ]]; then
    echo "$key.pub is not a public key." >&2
    exit 1
  fi
}

rc_set_local_alias() {
  local before after
  before=$(cat ~/.ssh/config 2>/dev/null || true)
  RC_ALIAS_NAME=$1 RC_ALIAS_ADDRESS=$1 RC_ALIAS_USER=$2 sh "$rc_vpn_dir/remote-trust.sh"
  after=$(cat ~/.ssh/config)
  if [[ $before != "$after" ]]; then echo "Saved SSH alias $1 for $2@$1." >&2; fi
}

rc_remote_script() {
  printf 'RC_PRINT_KEYS=1\n'
  if [[ $1 -eq 1 ]]; then printf "RC_KEY='%s %s %s@%s'\n" "$rc_key_type" "$rc_key_blob" "$rc_user" "$rc_name"; fi
  if [[ -n $2 ]]; then printf "RC_ALIAS_NAME='%s'\nRC_ALIAS_ADDRESS='%s'\nRC_ALIAS_USER='%s'\n" "$rc_name" "$2" "$rc_user"; fi
  cat "$rc_vpn_dir/remote-trust.sh"
}

rc_read_remote_keys() {
  local target=$1 alias=$1 address='' lan status=0
  if [[ $target == *@* ]]; then
    alias=${target#*@}
    rc_set_local_alias "$alias" "${target%%@*}"
  fi
  if lan=$(rc_home_lan); then
    address=${lan#* }
    rc_network_trust_warning "${lan%% *}" "$alias"
  else
    echo "This computer is not on the home network ($RC_VPN_HOME_NETWORK), so $alias will not get an SSH alias for it." >&2
  fi
  echo "Reading the keys trusted by $alias." >&2
  rc_remote_keys=$(rc_remote_script 0 "$address" | ssh -o BatchMode=yes "$alias" sh -s) || status=$?
  if [[ $status -eq 255 ]]; then
    echo "Key login to $alias failed. Log in with its password to install this computer's key there." >&2
    status=0
    rc_remote_keys=$(rc_remote_script 1 "$address" | ssh "$alias" sh -s) || status=$?
  fi
  if [[ $status -ne 0 ]]; then
    echo "ssh $alias failed with exit code $status." >&2
    exit 1
  fi
  if [[ -n $address ]]; then echo "From $alias, reach this computer with: ssh $rc_name" >&2; fi
}

rc_read_pasted_keys() {
  local line
  echo 'Paste public keys, one per line (from ~/.ssh/id_ed25519.pub on each device), then press Enter on an empty line.' >&2
  while IFS= read -r line && [[ -n $line ]]; do printf '%s\n' "$line"; done
}

rc_add_keys() {
  local exclude=${1:-} line type blob comment added=0
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  touch "$rc_keys_file" && chmod 600 "$rc_keys_file"
  while IFS= read -r line || [[ -n $line ]]; do
    type='' blob='' comment=''
    read -r type blob comment <<<"$line" || true
    if [[ -z $type || $type == \#* ]]; then continue; fi
    if [[ ! $type =~ $rc_key_pattern || ! $blob =~ $rc_blob_pattern ]]; then
      echo 'Skipped a line that is not a plain public key, such as one with command= or from= options.' >&2
    elif [[ -n $exclude && $blob == "$exclude" ]]; then
      echo "Skipped this computer's own key: $comment"
    elif grep -qF -- "$blob" "$rc_keys_file"; then
      echo "Already authorized: $comment"
    else
      if [[ -s $rc_keys_file && -n $(tail -c 1 "$rc_keys_file") ]]; then printf '\n' >> "$rc_keys_file"; fi
      printf '%s %s%s\n' "$type" "$blob" "${comment:+ $comment}" >> "$rc_keys_file"
      added=$((added + 1))
      echo "Added: $comment"
    fi
  done
  echo "Added $added key(s)."
}

rc_add_key() {
  local address
  if [[ $# -gt 0 ]]; then
    if [[ ! $1 =~ $rc_target_pattern ]]; then
      echo "Give an SSH alias or user@host, such as user@server: $1" >&2
      exit 1
    fi
    rc_identity
    rc_own_key
    rc_read_remote_keys "$1"
    rc_add_keys "$rc_key_blob" <<<"$rc_remote_keys"
  else
    rc_add_keys <<<"$(rc_read_pasted_keys)"
  fi
  if address=$(rc_vpn_address); then echo "From those devices, connect with: ssh $(id -un)@$address"; fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then rc_add_key "$@"; fi
