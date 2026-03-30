#!/usr/bin/env bash
set -euo pipefail

log()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*" >&2; }
err()  { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

SERVICE_NAME="rc-vm-auto-shutdown.service"
TIMER_NAME="rc-vm-auto-shutdown.timer"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"
TIMER_PATH="/etc/systemd/system/${TIMER_NAME}"
DISABLED_MARKER_PATH="/etc/systemd/system/rc-vm-auto-shutdown.disabled"
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
    err "sudo is required to inspect and edit the auto-shutdown systemd timer."
    exit 1
  fi

  if sudo -n true >/dev/null 2>&1; then
    return 0
  fi

  warn "This script needs sudo access to inspect and edit the auto-shutdown systemd timer."
  sudo true
}

require_systemd() {
  if ! command -v systemctl >/dev/null 2>&1; then
    err "systemctl is required to manage the auto-shutdown timer."
    exit 1
  fi
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

timezone_exists() {
  local tz="$1"

  if command -v timedatectl >/dev/null 2>&1; then
    timedatectl list-timezones 2>/dev/null | grep -Fxq "$tz"
    return $?
  fi

  [[ -f "/usr/share/zoneinfo/$tz" ]]
}

print_common_timezone_examples() {
  cat <<'EOF'
Common timezone values to enter:

US Pacific               America/Los_Angeles
US Mountain              America/Denver
US Central               America/Chicago
US Eastern               America/New_York
UK                       Europe/London
Central Europe           Europe/Berlin
Eastern Europe           Europe/Bucharest
UTC                      UTC
EOF
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

prompt_timezone() {
  local default_tz="$1" value
  while true; do
    read -r -p "Timezone for shutdown schedule [$default_tz]: " value
    value="${value:-$default_tz}"
    if [[ -z "$value" ]]; then
      warn "Timezone cannot be empty."
      continue
    fi
    if timezone_exists "$value"; then
      printf '%s\n' "$value"
      return 0
    fi
    warn "Timezone not found: $value"
    if command -v timedatectl >/dev/null 2>&1; then
      printf 'Try a value from: timedatectl list-timezones\n' >&2
    else
      printf 'Try a value like: UTC or America/Los_Angeles\n' >&2
    fi
  done
}

disabled_marker_exists() {
  sudo test -f "$DISABLED_MARKER_PATH"
}

timer_unit_exists() {
  sudo test -f "$TIMER_PATH"
}

service_unit_exists() {
  sudo test -f "$SERVICE_PATH"
}

timer_is_enabled() {
  sudo systemctl is-enabled --quiet "$TIMER_NAME"
}

timer_is_active() {
  sudo systemctl is-active --quiet "$TIMER_NAME"
}

cleanup_managed_units() {
  sudo systemctl disable --now "$TIMER_NAME" >/dev/null 2>&1 || true
  sudo rm -f "$SERVICE_PATH" "$TIMER_PATH"
  sudo systemctl daemon-reload
}

write_root_file() {
  local path="$1" content="$2" tmp
  tmp="$(mktemp)"
  printf '%s' "$content" > "$tmp"
  sudo install -m 0644 "$tmp" "$path"
  rm -f "$tmp"
}

write_disabled_marker() {
  cleanup_managed_units
  write_root_file "$DISABLED_MARKER_PATH" "disabled\n"
}

remove_disabled_marker() {
  sudo rm -f "$DISABLED_MARKER_PATH"
}

install_timer_units() {
  local shutdown_hour="$1" schedule_timezone="$2"
  local service_unit timer_unit

  service_unit="$(cat <<EOF
[Unit]
Description=Shut down VM

[Service]
Type=oneshot
ExecStart=${SHUTDOWN_COMMAND}
EOF
)"

  timer_unit="$(cat <<EOF
[Unit]
Description=Daily VM auto-shutdown

[Timer]
Timezone=${schedule_timezone}
OnCalendar=*-*-* $(printf '%02d' "$shutdown_hour"):00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF
)"

  remove_disabled_marker
  write_root_file "$SERVICE_PATH" "$service_unit"
  write_root_file "$TIMER_PATH" "$timer_unit"
  sudo systemctl daemon-reload
  sudo systemctl enable --now "$TIMER_NAME" >/dev/null
}

print_timer_edit_hint() {
  printf 'Inspect later with: sudo systemctl status %s\n' "$TIMER_NAME"
  printf 'Edit later with: sudoedit %s %s && sudo systemctl daemon-reload && sudo systemctl restart %s\n' \
    "$SERVICE_PATH" "$TIMER_PATH" "$TIMER_NAME"
}

if ! is_vm; then
  log "Not running on a VM. No auto-shutdown check needed."
  exit 0
fi

require_sudo
require_systemd

if disabled_marker_exists; then
  log "Auto-shutdown is explicitly disabled."
  exit 0
fi

if timer_unit_exists || service_unit_exists || timer_is_enabled || timer_is_active; then
  log "A systemd auto-shutdown timer already exists."
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
    write_disabled_marker
    log "Wrote auto-shutdown disabled marker."
    print_timer_edit_hint
    exit 0
    ;;
esac

timezone_name="$(get_timezone)"
printf 'VM timezone: %s\n' "$timezone_name"
if [[ "$timezone_name" == *UTC* ]]; then
  printf '\n'
  print_common_timezone_examples
  printf '\n'
fi

schedule_timezone="$(prompt_timezone "$timezone_name")"
printf 'Shutdown schedule timezone: %s\n' "$schedule_timezone"
shutdown_hour="$(prompt_hour)"
install_timer_units "$shutdown_hour" "$schedule_timezone"

log "Configured daily auto-shutdown at $(printf '%02d' "$shutdown_hour"):00 in timezone $schedule_timezone."
print_timer_edit_hint
