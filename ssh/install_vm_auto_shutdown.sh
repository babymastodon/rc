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
MODE="${1:-check}"
COMMON_TIMEZONE_LABELS=(
  "US Pacific"
  "US Mountain"
  "US Central"
  "US Eastern"
  "UK"
  "Central Europe"
  "Eastern Europe"
  "UTC"
)
COMMON_TIMEZONE_VALUES=(
  "America/Los_Angeles"
  "America/Denver"
  "America/Chicago"
  "America/New_York"
  "Europe/London"
  "Europe/Berlin"
  "Europe/Bucharest"
  "UTC"
)

usage() {
  cat <<'EOF' >&2
Usage: install_vm_auto_shutdown.sh [check|edit]

Modes:
  check  Default. Only prompts when no auto-shutdown is configured yet.
  edit   Reconfigure or disable the managed auto-shutdown timer.
EOF
  exit 1
}

case "$MODE" in
  check|edit)
    ;;
  *)
    usage
    ;;
esac

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
  local index
  printf 'Common timezone values:\n\n'
  for index in "${!COMMON_TIMEZONE_VALUES[@]}"; do
    printf '%2d) %-18s %s\n' "$((index + 1))" "${COMMON_TIMEZONE_LABELS[$index]}" "${COMMON_TIMEZONE_VALUES[$index]}"
  done
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
  local default_hour="${1:-}" value prompt
  if [[ -n "$default_hour" ]]; then
    prompt="Hour of day for shutdown in selected timezone [0-23] [$default_hour]: "
  else
    prompt="Hour of day for shutdown in selected timezone [0-23]: "
  fi

  while true; do
    read -r -p "$prompt" value
    value="${value:-$default_hour}"
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
  local default_tz="$1" value index
  while true; do
    read -r -p "Timezone for shutdown schedule (number or value) [$default_tz]: " value
    value="${value:-$default_tz}"
    if [[ -z "$value" ]]; then
      warn "Timezone cannot be empty."
      continue
    fi
    if [[ "$value" =~ ^[0-9]+$ ]]; then
      index=$((10#$value - 1))
      if (( index >= 0 && index < ${#COMMON_TIMEZONE_VALUES[@]} )); then
        value="${COMMON_TIMEZONE_VALUES[$index]}"
      else
        warn "Timezone number must be between 1 and ${#COMMON_TIMEZONE_VALUES[@]}."
        continue
      fi
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
  sudo systemctl is-enabled --quiet "$TIMER_NAME" >/dev/null 2>&1
}

timer_is_active() {
  sudo systemctl is-active --quiet "$TIMER_NAME" >/dev/null 2>&1
}

read_timer_setting() {
  local key="$1" value
  value="$(sudo systemctl cat "$TIMER_NAME" 2>/dev/null | awk -F= -v key="$key" '$1 == key {print $2; exit}')"
  printf '%s\n' "$value"
}

extract_hour_from_calendar() {
  local calendar="$1"
  if [[ "$calendar" =~ ([0-9]{2}):00:00([[:space:]]+[[:alnum:]_./+-]+)?$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]#0}"
    return 0
  fi
  return 1
}

extract_timezone_from_calendar() {
  local calendar="$1"
  if [[ "$calendar" =~ [0-9]{2}:[0-9]{2}:[0-9]{2}[[:space:]]+([[:alnum:]_./+-]+)$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
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
OnCalendar=*-*-* $(printf '%02d' "$shutdown_hour"):00:00 ${schedule_timezone}
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
  printf 'Reconfigure later with: %s edit\n' "$0"
  printf 'Manual edit: sudoedit %s %s && sudo systemctl daemon-reload && sudo systemctl restart %s\n' \
    "$SERVICE_PATH" "$TIMER_PATH" "$TIMER_NAME"
}

if ! is_vm; then
  log "Not running on a VM. No auto-shutdown check needed."
  exit 0
fi

require_sudo
require_systemd

has_existing_timer=false

if [[ "$MODE" == "check" ]] && disabled_marker_exists; then
  log "Auto-shutdown is explicitly disabled."
  exit 0
fi

if [[ "$MODE" == "check" ]] && ( timer_unit_exists || service_unit_exists || timer_is_enabled || timer_is_active ); then
  log "A systemd auto-shutdown timer already exists."
  print_timer_edit_hint
  exit 0
fi

if [[ "$MODE" == "edit" ]]; then
  if disabled_marker_exists; then
    log "Auto-shutdown is currently disabled."
  elif timer_unit_exists || service_unit_exists || timer_is_enabled || timer_is_active; then
    has_existing_timer=true
    current_calendar="$(read_timer_setting OnCalendar)"
    current_hour="$(extract_hour_from_calendar "$current_calendar" || true)"
    current_timezone="$(extract_timezone_from_calendar "$current_calendar" || true)"
    log "Editing existing systemd auto-shutdown timer."
    if [[ -n "$current_calendar" ]]; then
      printf 'Current timer schedule: %s\n' "$current_calendar"
    fi
  else
    warn "No existing auto-shutdown timer found. Edit mode will create one."
  fi
else
  warn "This VM does not have any auto-shutdown configured. Leaving it on can lead to hundreds of dollars of increased cost."
fi

choice="$(prompt_choice)"
case "$choice" in
  no)
    if [[ "$MODE" == "edit" && "$has_existing_timer" == true ]]; then
      cleanup_managed_units
      log "Disabled managed auto-shutdown timer."
      exit 0
    fi
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
printf '\n'
print_common_timezone_examples
printf '\n'

timezone_default="$timezone_name"
hour_default=""
if [[ "$MODE" == "edit" ]]; then
  if [[ -n "${current_timezone:-}" ]]; then
    timezone_default="$current_timezone"
  fi
  if [[ -n "${current_hour:-}" ]]; then
    hour_default="$current_hour"
  fi
fi

schedule_timezone="$(prompt_timezone "$timezone_default")"
printf 'Shutdown schedule timezone: %s\n' "$schedule_timezone"
shutdown_hour="$(prompt_hour "$hour_default")"
install_timer_units "$shutdown_hour" "$schedule_timezone"

log "Configured daily auto-shutdown at $(printf '%02d' "$shutdown_hour"):00 in timezone $schedule_timezone."
print_timer_edit_hint
