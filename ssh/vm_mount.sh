#!/usr/bin/env bash
set -euo pipefail

log()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

usage() {
  cat <<'EOF'
Usage: vm_mount.sh <ssh-alias> [umount]

Mounts /home/<remote-user> for the SSH alias at ~/vmfs/<ssh-alias> using
sshfs. If "umount" is passed, only unmounts ~/vmfs/<ssh-alias>.
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage >&2
  exit 1
fi

alias_name="$1"
action="${2:-mount}"
os="$(uname -s)"

if [[ "$action" != "mount" && "$action" != "umount" ]]; then
  usage >&2
  exit 1
fi

if ! command -v ssh >/dev/null 2>&1; then
  err "ssh is required."
  exit 1
fi

if ! command -v sshfs >/dev/null 2>&1; then
  err "sshfs is required. Install it with ./install_sshfs.sh from the ssh directory."
  exit 1
fi

if ! command -v umount >/dev/null 2>&1; then
  err "umount is required."
  exit 1
fi

resolved="$(ssh -G "$alias_name" 2>/dev/null)" || {
  err "Failed to resolve SSH alias: $alias_name"
  exit 1
}

get_ssh_value() {
  local key="$1"
  printf '%s\n' "$resolved" | awk -v wanted="$key" '$1 == wanted { $1=""; sub(/^ /, ""); print; exit }'
}

hostname_value="$(get_ssh_value hostname)"
user_value="$(get_ssh_value user)"
port_value="$(get_ssh_value port)"

if [[ -z "$hostname_value" ]]; then
  err "SSH alias $alias_name does not define HostName."
  exit 1
fi

if [[ "$hostname_value" == "$alias_name" ]]; then
  err "SSH alias $alias_name was not found in ~/.ssh/config."
  exit 1
fi

if [[ -z "$user_value" ]]; then
  err "SSH alias $alias_name does not define User."
  exit 1
fi

if [[ -z "$port_value" ]]; then
  port_value="22"
fi

remote_path="/home/$user_value"
mount_root="$HOME/vmfs"
mount_dir="$mount_root/$alias_name"

mkdir -p "$mount_dir"

is_mounted() {
  if command -v findmnt >/dev/null 2>&1; then
    findmnt -rn --mountpoint "$mount_dir" >/dev/null 2>&1
  else
    mount | grep -Fq "on $mount_dir "
  fi
}

force_unmount() {
  case "$os" in
    Darwin)
      diskutil unmount force "$mount_dir" >/dev/null
      ;;
    Linux)
      umount -l "$mount_dir"
      ;;
    *)
      err "vm_mount.sh only supports Linux and macOS. Detected: $os"
      exit 1
      ;;
  esac
}

if is_mounted; then
  log "Unmounting existing mount at $mount_dir"
  umount "$mount_dir" || {
    warn "Regular unmount failed, retrying forced unmount."
    force_unmount
  }
elif [[ "$action" == "umount" ]]; then
  err "$mount_dir is not mounted."
  exit 1
fi

if [[ "$action" == "umount" ]]; then
  log "Unmounted $mount_dir"
  exit 0
fi

log "Mounting $alias_name:$remote_path at $mount_dir"
sshfs_opts=(reconnect)

case "$os" in
  Darwin)
    sshfs_opts+=(auto_cache defer_permissions "volname=$alias_name")
    ;;
  Linux)
    ;;
  *)
    err "vm_mount.sh only supports Linux and macOS. Detected: $os"
    exit 1
    ;;
esac

sshfs "$alias_name:$remote_path" "$mount_dir" \
  -p "$port_value" \
  -o "$(IFS=,; printf '%s' "${sshfs_opts[*]}")"

log "Mounted at $mount_dir"
log "To unmount later, run: vmfs $alias_name umount"
