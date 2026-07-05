#!/usr/bin/env bash
set -euo pipefail

log()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }
need_sudo() { if [[ $EUID -ne 0 ]]; then printf 'sudo'; fi; }
SUDO="$(need_sudo || true)"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
TERMINAL_LIST="${XDG_TERMINALS_LIST:-$CONFIG_HOME/xdg-terminals.list}"
TERMINAL_CACHE="${XDG_TERMINAL_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/xdg-terminal-exec}"

SELECTED_NAME=""
SELECTED_DESKTOP=""
SELECTED_VENDOR_DESKTOP=""

usage() {
  cat <<EOF
Usage: $0 [kitty|ghostty|alacritty]

Installs xdg-terminal-exec and configures the selected terminal as the default.
Without an argument, preference order is kitty, ghostty, then alacritty.
EOF
}

install_xdg_terminal_exec() {
  if command -v xdg-terminal-exec >/dev/null 2>&1; then
    log "xdg-terminal-exec is already installed."
    return
  fi

  if command -v dnf >/dev/null 2>&1; then
    log "Installing xdg-terminal-exec with DNF..."
    $SUDO dnf -y install xdg-terminal-exec
  elif command -v apt-get >/dev/null 2>&1; then
    log "Installing xdg-terminal-exec with APT..."
    $SUDO apt-get update
    $SUDO apt-get install -y xdg-terminal-exec
  else
    err "No supported package manager found. Install xdg-terminal-exec manually."
    return 1
  fi

  if ! command -v xdg-terminal-exec >/dev/null 2>&1; then
    err "xdg-terminal-exec was not found after installation."
    return 1
  fi
}

desktop_entry_exists() {
  local desktop_id="$1"
  local dir

  [[ -f "$DATA_HOME/applications/$desktop_id" ]] && return 0
  while IFS= read -r dir; do
    [[ -f "$dir/applications/$desktop_id" ]] && return 0
  done < <(tr ':' '\n' <<<"$DATA_DIRS")
  return 1
}

select_known_terminal() {
  local name="$1"
  local command_name
  local -a desktop_ids

  case "${name,,}" in
    kitty)
      SELECTED_NAME="kitty"
      command_name="kitty"
      desktop_ids=(kitty.desktop)
      ;;
    ghostty)
      SELECTED_NAME="ghostty"
      command_name="ghostty"
      desktop_ids=(com.mitchellh.ghostty.desktop ghostty.desktop)
      ;;
    alacritty)
      SELECTED_NAME="alacritty"
      command_name="alacritty"
      desktop_ids=(Alacritty.desktop alacritty.desktop)
      ;;
    *) return 1 ;;
  esac

  command -v "$command_name" >/dev/null 2>&1 || return 1
  for SELECTED_VENDOR_DESKTOP in "${desktop_ids[@]}"; do
    if desktop_entry_exists "$SELECTED_VENDOR_DESKTOP"; then
      return 0
    fi
  done

  SELECTED_VENDOR_DESKTOP=""
  return 1
}

select_terminal() {
  local requested="${1:-}"
  local candidate

  if [[ -n "$requested" ]]; then
    if ! select_known_terminal "$requested"; then
      err "Requested terminal is unavailable or has no desktop entry: $requested"
      return 1
    fi
    return
  fi

  for candidate in kitty ghostty alacritty; do
    if select_known_terminal "$candidate"; then
      return
    fi
  done

  err "No supported terminal was found (tried kitty, ghostty, and alacritty)."
  return 1
}

install_terminal_entry() {
  local desktop_path
  local tmp_file

  SELECTED_DESKTOP="rc-${SELECTED_NAME}-xdg-terminal.desktop"
  desktop_path="$DATA_HOME/applications/$SELECTED_DESKTOP"
  mkdir -p "$(dirname "$desktop_path")"
  tmp_file="$(mktemp "$(dirname "$desktop_path")/.${SELECTED_DESKTOP}.XXXXXX")"

  case "$SELECTED_NAME" in
    kitty)
      cat > "$tmp_file" <<'EOF'
[Desktop Entry]
Type=Application
Name=Kitty (xdg-terminal-exec)
Comment=Managed terminal metadata for xdg-terminal-exec
TryExec=kitty
Exec=kitty
Icon=kitty
Terminal=false
NoDisplay=true
Categories=System;TerminalEmulator;
X-TerminalArgExec=
X-TerminalArgAppId=--app-id=
X-TerminalArgTitle=--title=
X-TerminalArgDir=--directory=
X-TerminalArgHold=--hold
EOF
      ;;
    ghostty)
      cat > "$tmp_file" <<'EOF'
[Desktop Entry]
Type=Application
Name=Ghostty (xdg-terminal-exec)
Comment=Managed terminal metadata for xdg-terminal-exec
TryExec=ghostty
Exec=ghostty
Icon=com.mitchellh.ghostty
Terminal=false
NoDisplay=true
Categories=System;TerminalEmulator;
X-TerminalArgExec=-e
X-TerminalArgAppId=--class=
X-TerminalArgTitle=--title=
X-TerminalArgDir=--working-directory=
X-TerminalArgHold=--wait-after-command
EOF
      ;;
    alacritty)
      cat > "$tmp_file" <<'EOF'
[Desktop Entry]
Type=Application
Name=Alacritty (xdg-terminal-exec)
Comment=Managed terminal metadata for xdg-terminal-exec
TryExec=alacritty
Exec=alacritty
Icon=Alacritty
Terminal=false
NoDisplay=true
Categories=System;TerminalEmulator;
X-TerminalArgExec=-e
X-TerminalArgAppId=--class=
X-TerminalArgTitle=--title=
X-TerminalArgDir=--working-directory=
X-TerminalArgHold=--hold
EOF
      ;;
  esac

  chmod 0644 "$tmp_file"
  mv -f "$tmp_file" "$desktop_path"
  update-desktop-database "$DATA_HOME/applications" >/dev/null 2>&1 || true
  log "Installed xdg-terminal-exec metadata: $desktop_path"
}

write_terminal_list() {
  local tmp_file

  mkdir -p "$(dirname "$TERMINAL_LIST")"
  tmp_file="$(mktemp "$(dirname "$TERMINAL_LIST")/.xdg-terminals.list.XXXXXX")"

  printf '%s\n' "$SELECTED_DESKTOP" > "$tmp_file"
  if [[ -f "$TERMINAL_LIST" ]]; then
    awk -v selected="$SELECTED_DESKTOP" '$0 != selected { print }' "$TERMINAL_LIST" >> "$tmp_file"
  fi

  chmod 0644 "$tmp_file"
  mv -f "$tmp_file" "$TERMINAL_LIST"
  rm -f "$TERMINAL_CACHE"
  log "Set the default terminal to ${SELECTED_NAME} (${SELECTED_DESKTOP})."
}

verify_terminal() {
  local actual
  actual="$(xdg-terminal-exec --print-id 2>/dev/null || true)"
  if [[ "$actual" == "$SELECTED_DESKTOP" ]]; then
    log "Verified xdg-terminal-exec selection: $actual"
  else
    warn "Configured ${SELECTED_DESKTOP}, but xdg-terminal-exec reported: ${actual:-<none>}"
  fi
}

main() {
  if [[ $# -gt 1 ]]; then
    usage >&2
    return 2
  fi
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    return
  fi

  install_xdg_terminal_exec
  select_terminal "${1:-}"
  install_terminal_entry
  write_terminal_list
  verify_terminal
}

main "$@"
