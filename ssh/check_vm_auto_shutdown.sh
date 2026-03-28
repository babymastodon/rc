#!/usr/bin/env bash
set -euo pipefail

log()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*" >&2; }
err()  { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

DISABLED_COMMENT="# rc-vm-auto-shutdown: disabled"
MANAGED_COMMENT="# rc-vm-auto-shutdown: enabled"
SHUTDOWN_COMMAND="/sbin/shutdown -h now"

is_vm() {
  if command -v systemd-detect-virt >/dev/null 2>&1; then
    systemd-detect-virt --quiet
    return $?
  fi

  if [[ -f /sys/class/dmi/id/product_name ]]; then
    grep -Eiq '(virtual|kvm|vmware|virtualbox|qemu|hyper-v|parallels|amazon ec2|google compute engine)' /sys/class/dmi/id/product_name
    return $?
  fi

  return 1
}

require_sudo() {
  if ! command -v sudo >/dev/null 2>&1; then
    err "sudo is required to inspect and edit the shutdown crontab."
    exit 1
  fi

  if sudo -n true >/dev/null 2>&1; then
    return 0
  fi

  warn "This script needs sudo access to inspect the root crontab."
  sudo true
}

get_root_crontab() {
  sudo crontab -l 2>/dev/null || true
}

get_timezone() {
  local tz=""
  if command -v timedatectl >/dev/null 2>&1; then
    tz="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
  fi
  if [[ -z "$tz" && -f /etc/timezone ]]; then
    tz="$(cat /etc/timezone 2>/dev/null || true)"
  fi
  if [[ -z "$tz" ]]; then
    tz="$(date +%Z)"
  fi
  printf '%s\n' "$tz"
}

print_utc_reference_table() {
  cat <<'EOF'
UTC reference for local midnight:

Timezone                 Midnight local = UTC
US Pacific               08:00 UTC
US Mountain              07:00 UTC
US Central               06:00 UTC
US Eastern               05:00 UTC
UK                       00:00 UTC
Central Europe           23:00 UTC
Eastern Europe           22:00 UTC
EOF
}

has_disabled_marker() {
  grep -Fqx "$DISABLED_COMMENT" <<<"$1"
}

has_shutdown_schedule() {
  local crontab_text="$1"
  grep -Eq '(^|[[:space:]])(shutdown|/sbin/shutdown)([[:space:]]|$)' <<<"$crontab_text"
}

prompt_choice() {
  local value normalized
  while true; do
    read -r -p "Enable auto-shutdown? [yes/no/don't ask me again] [yes]: " value
    normalized="${value:-yes}"
    normalized="$(printf '%s' "$normalized" | tr '[:upper:]' '[:lower:]')"
    case "$normalized" in
      y|yes) printf 'yes\n'; return 0 ;;
      n|no) printf 'no\n'; return 0 ;;
      "don't ask me again"|dontask|disable|disabled|never)
        printf "don't ask me again\n"
        return 0
        ;;
    esac
    warn "Please answer yes, no, or don't ask me again."
  done
}

prompt_hour() {
  local value
  while true; do
    read -r -p "Hour of day for shutdown in local VM time [0-23]: " value
    if [[ ! "$value" =~ ^[0-9]+$ ]]; then
      warn "Enter an integer hour between 0 and 23."
      continue
    fi
    if (( value < 0 || value > 23 )); then
      warn "Hour must be between 0 and 23."
      continue
    fi
    printf '%s\n' "$value"
    return 0
  done
}

install_root_crontab() {
  local content="$1" tmp
  tmp="$(mktemp)"
  printf '%s\n' "$content" > "$tmp"
  sudo crontab "$tmp"
  rm -f "$tmp"
}

strip_managed_lines() {
  local current="$1"
  printf '%s\n' "$current" | awk -v disabled="$DISABLED_COMMENT" -v enabled="$MANAGED_COMMENT" -v cmd="$SHUTDOWN_COMMAND" '
    $0 == disabled { next }
    $0 == enabled { next }
    index($0, cmd) > 0 { next }
    { print }
  '
}

append_entry() {
  local base="$1" extra="$2"
  if [[ -n "$base" ]]; then
    printf '%s\n%s\n' "$base" "$extra"
  else
    printf '%s\n' "$extra"
  fi
}

if ! is_vm; then
  log "Not running on a VM. No auto-shutdown check needed."
  exit 0
fi

require_sudo

current_crontab="$(get_root_crontab)"

if has_disabled_marker "$current_crontab"; then
  log "Auto-shutdown is explicitly disabled in root crontab."
  exit 0
fi

if has_shutdown_schedule "$current_crontab"; then
  log "A shutdown cron entry already exists in root crontab."
  exit 0
fi

warn "This VM does not have any auto-shutdown configured. Leaving it on can lead to hundreds of dollars of increased cost."

choice="$(prompt_choice)"
case "$choice" in
  no)
    log "No changes made."
    exit 0
    ;;
  "don't ask me again")
    new_crontab="$(append_entry "$(strip_managed_lines "$current_crontab")" "$DISABLED_COMMENT")"
    install_root_crontab "$new_crontab"
    log "Wrote disabled marker to root crontab."
    printf 'Edit later with: sudo crontab -e\n'
    exit 0
    ;;
esac

timezone_name="$(get_timezone)"
printf 'VM timezone: %s\n' "$timezone_name"
if [[ "$timezone_name" == "UTC" ]]; then
  printf '\n'
  print_utc_reference_table
  printf '\n'
fi

shutdown_hour="$(prompt_hour)"
managed_block="$(cat <<EOF
$MANAGED_COMMENT
0 $shutdown_hour * * * $SHUTDOWN_COMMAND
EOF
)"

new_crontab="$(append_entry "$(strip_managed_lines "$current_crontab")" "$managed_block")"
install_root_crontab "$new_crontab"

log "Configured daily auto-shutdown at ${shutdown_hour}:00 in timezone $timezone_name."
printf 'Edit later with: sudo crontab -e\n'
