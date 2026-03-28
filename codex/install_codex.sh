#!/usr/bin/env bash
set -euo pipefail

log()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

AUTH_PORT="${CODEX_AUTH_PORT:-1455}"

maybe_link() {
  local src="$1" dest="$2"

  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ -L "$dest" ]]; then
      local target
      target="$(readlink "$dest")"
      if [[ "$target" == "$src" ]]; then
        log "Link already correct: $dest -> $src"
      else
        warn "Link exists but wrong target ($target), fixing..."
        rm -f "$dest"
        ln -s "$src" "$dest"
        log "Fixed link: $dest -> $src"
      fi
    else
      local backup="${dest}.bak"
      warn "Exists and not a link: $dest (backing up to $backup and replacing)"
      mv -f "$dest" "$backup"
      ln -s "$src" "$dest"
      log "Linked: $dest -> $src"
    fi
  else
    ln -s "$src" "$dest"
    log "Linked: $dest -> $src"
  fi
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
  printf 'Run `cd ../vim && ./install_coc.sh` first to install the shared language tooling, then rerun this script.\n' >&2
  exit 1
fi

if command -v codex >/dev/null 2>&1; then
  log "Codex already installed: $(codex --version 2>/dev/null | head -n1 || echo 'version lookup skipped')"
else
  log "Installing @openai/codex via npm..."
  npm install -g @openai/codex
fi

mkdir -p "$HOME/.codex"
maybe_link "$PWD/config.toml" "$HOME/.codex/config.toml"

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
