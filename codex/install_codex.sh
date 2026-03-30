#!/usr/bin/env bash
set -euo pipefail

log()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

AUTH_PORT="${CODEX_AUTH_PORT:-1455}"

print_shell_setup_guidance() {
  printf 'Run `./install.sh` from the repo root, then `source ~/.bashrc`, then rerun this script.\n' >&2
}

require_env_vars() {
  local missing=() var
  for var in "$@"; do
    if [[ -z "${!var:-}" ]]; then
      missing+=("$var")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    err "Missing required environment variable(s): ${missing[*]}"
    print_shell_setup_guidance
    exit 1
  fi
}

ensure_ansi_theme_comment() {
  local dest="$1" tmp

  mkdir -p "$(dirname "$dest")"
  tmp="$(mktemp)"

  if [[ -f "$dest" ]]; then
    awk '
      BEGIN { theme_done=0; header_done=0; url_done=0 }
      /^# Use the basic ANSI theme because Codex'\''s TUI is still hard to read in light-theme terminals:/ {
        if (!header_done) {
          print "# Use the basic ANSI theme because Codex'\''s TUI is still hard to read in light-theme terminals:"
          header_done=1
        }
        next
      }
      /^# https:\/\/github\.com\/openai\/codex\/issues\/2020$/ {
        if (!header_done) {
          print "# Use the basic ANSI theme because Codex'\''s TUI is still hard to read in light-theme terminals:"
          header_done=1
        }
        if (!url_done) {
          print "# https://github.com/openai/codex/issues/2020"
          url_done=1
        }
        next
      }
      /^theme[[:space:]]*=/ {
        if (!header_done) {
          print "# Use the basic ANSI theme because Codex'\''s TUI is still hard to read in light-theme terminals:"
          header_done=1
        }
        if (!url_done) {
          print "# https://github.com/openai/codex/issues/2020"
          url_done=1
        }
        print "theme = \"ansi\""
        theme_done=1
        next
      }
      { print }
      END {
        if (!header_done) {
          print "# Use the basic ANSI theme because Codex'\''s TUI is still hard to read in light-theme terminals:"
        }
        if (!url_done) {
          print "# https://github.com/openai/codex/issues/2020"
        }
        if (!theme_done) {
          print "theme = \"ansi\""
        }
      }
    ' "$dest" > "$tmp"
  else
    cat > "$tmp" <<'EOF'
# Use the basic ANSI theme because Codex's TUI is still hard to read in light-theme terminals:
# https://github.com/openai/codex/issues/2020
theme = "ansi"
EOF
  fi

  mv "$tmp" "$dest"
  log "Updated $dest"
}

is_vm() {
  if command -v systemd-detect-virt >/dev/null 2>&1; then
    systemd-detect-virt --quiet
    return $?
  fi

  if [[ -f /sys/class/dmi/id/product_name ]]; then
    grep -Eiq '(virtual|kvm|vmware|virtualbox|qemu|hyper-v|parallels)' /sys/class/dmi/id/product_name
    return $?
  fi

  return 1
}

print_vm_instructions() {
  local host user ssh_target
  host="$(hostname -f 2>/dev/null || hostname)"
  user="${USER:-your-user}"
  ssh_target="${CODEX_SSH_TARGET:-${user}@${host}}"

  warn "Virtual machine detected."
  printf 'Run this on your laptop before logging in:\n\n'
  printf '  ssh -L %s:localhost:%s %s\n\n' "$AUTH_PORT" "$AUTH_PORT" "$ssh_target"
  printf 'Then run `codex` on the VM and choose ChatGPT login, not API key login.\n'
}

if ! command -v npm >/dev/null 2>&1; then
  err "npm is required to install Codex."
  print_shell_setup_guidance
  printf 'Then run `cd ../vim && ./install_languages.sh` first to install the shared language tooling, then rerun this script.\n' >&2
  exit 1
fi

require_env_vars NODEJS_HOME NPM_CONFIG_PREFIX
export PATH="${NODEJS_HOME}/bin:${NPM_CONFIG_PREFIX}/bin:$PATH"

if command -v codex >/dev/null 2>&1; then
  log "Codex already installed: $(codex --version 2>/dev/null | head -n1 || echo 'version lookup skipped')"
else
  log "Installing @openai/codex via npm..."
  npm install -g @openai/codex
fi

ensure_ansi_theme_comment "$HOME/.codex/config.toml"

if command -v codex >/dev/null 2>&1; then
  log "Codex installed: $(codex --version 2>/dev/null | head -n1 || echo 'version lookup skipped')"
else
  warn "Codex install finished, but `codex` is not on PATH in this shell yet."
fi

printf '\n'
if is_vm; then
  print_vm_instructions
else
  printf 'Next step: run `codex` on this machine and log in with ChatGPT, not an API key.\n'
fi
