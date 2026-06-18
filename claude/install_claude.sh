#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

log()  { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

print_shell_setup_guidance() {
  printf 'Run `./install.sh` from the repo root, then `source ~/.bashrc`, then rerun this script.\n' >&2
}

# Deep-merge the repo's tracked settings into ~/.claude/settings.json without
# clobbering keys that Claude Code (or the user) writes there itself. The repo
# file is the source of truth only for the keys it contains; everything else in
# the destination is preserved. Note: we manage settings.json only, never
# ~/.claude.json, which holds machine-specific state (machineID, oauth, etc.).
ensure_claude_settings() {
  local src="$1" dest="$2" tmp
  mkdir -p "$(dirname "$dest")"
  tmp="$(mktemp)"

  if [[ -f "$dest" ]]; then
    jq -s '.[0] * .[1]' "$dest" "$src" > "$tmp"
  else
    cp "$src" "$tmp"
  fi

  mv "$tmp" "$dest"
  log "Updated $dest"
}

# Install the repo's custom themes into ~/.claude/themes/. Claude Code reads each
# JSON file there as a theme whose slug is the filename; settings.json references
# one via "theme": "custom:<slug>". We copy (not symlink) since Claude Code also
# writes themes here via its interactive editor.
ensure_claude_themes() {
  local src_dir="$1" dest_dir="$2" f
  [[ -d "$src_dir" ]] || return 0
  mkdir -p "$dest_dir"
  for f in "$src_dir"/*.json; do
    [[ -e "$f" ]] || continue
    cp "$f" "$dest_dir/"
    log "Installed theme $(basename "$f")"
  done
}

if ! command -v jq >/dev/null 2>&1; then
  err "jq is required to merge Claude settings."
  print_shell_setup_guidance
  printf 'Then run `%s/mise/install_mise.sh` first to install the shared CLI tooling, then rerun this script.\n' "$REPO_ROOT" >&2
  exit 1
fi

# Install via the native installer (self-updating), not npm. This matches how
# `claude` lands at ~/.local/share/claude/versions/* with a ~/.local/bin/claude
# symlink and keeps auto-updates working.
if command -v claude >/dev/null 2>&1; then
  log "Claude Code already installed: $(claude --version 2>/dev/null | head -n1 || echo 'version lookup skipped')"
else
  log "Installing Claude Code via the native installer..."
  curl -fsSL https://claude.ai/install.sh | bash
fi

export PATH="${HOME}/.local/bin:$PATH"

ensure_claude_settings "$SCRIPT_DIR/settings.json" "$HOME/.claude/settings.json"
ensure_claude_themes "$SCRIPT_DIR/themes" "$HOME/.claude/themes"

if command -v claude >/dev/null 2>&1; then
  log "Claude Code installed: $(claude --version 2>/dev/null | head -n1 || echo 'version lookup skipped')"
else
  warn "Claude Code install finished, but \`claude\` is not on PATH in this shell yet."
fi

printf '\n'
printf 'Next step: run `claude`, then `/login` and authenticate in the browser.\n'
printf 'On a remote/headless machine, choose the option to paste the auth code\n'
printf '(no SSH port-forwarding required, unlike Codex).\n'
