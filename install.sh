#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ----- helpers -----
log()   { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }
need_sudo() { if [[ $EUID -ne 0 ]]; then echo "sudo"; fi; }
SUDO="$(need_sudo || true)"

maybe_link() {
  local src="$1" dest="$2"

  # If destination exists
  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ -L "$dest" ]]; then
      local target
      target="$(readlink "$dest")"
      if [[ "$target" == "$src" ]]; then
        log "Link already correct: $dest -> $src"
      else
        warn "Link exists but wrong target ($target), fixing..."
        rm "$dest"
        ln -s "$src" "$dest"
        log "Fixed link: $dest -> $src"
      fi
    else
      log "Exists and not a link: $dest (skipping)"
    fi
  else
    ln -s "$src" "$dest"
    log "Linked: $dest -> $src"
  fi
}

maybe_copy() {
  local src="$1" dest="$2"
  if [[ -e "$dest" ]]; then
    log "Exists, not copying: $dest"
  else
    cp "$src" "$dest"
    log "Copied: $src -> $dest"
  fi
}

sanitize_btop_config() {
  local conf="$1" tmp
  [[ -f "$conf" ]] || return 0

  if grep -Eq '^[[:space:]]*cpu_graph_(upper|lower)[[:space:]]*=[[:space:]]*"Auto"' "$conf"; then
    tmp="${conf}.tmp.$$"
    awk '
      /^[[:space:]]*cpu_graph_upper[[:space:]]*=/ { print "cpu_graph_upper = \"total\""; next }
      /^[[:space:]]*cpu_graph_lower[[:space:]]*=/ { print "cpu_graph_lower = \"total\""; next }
      { print }
    ' "$conf" > "$tmp"
    mv "$tmp" "$conf"
    warn "Updated btop CPU graph fields from Auto to total for older btop compatibility."
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

ensure_source_in_file() {
  local src="$1" file="$2"
  local name="$(basename "$src")"
  mkdir -p "$(dirname "$file")"
  touch "$file"

  # Remove any existing lines sourcing the same filename
  grep -vE "^[[:space:]]*source[[:space:]]+.*${name}$" "$file" > "$file.tmp" || true
  mv "$file.tmp" "$file"

  # Add the new source line if not already present
  if ! grep -qxF "source $src" "$file"; then
    echo "source $src" >> "$file"
    log "Added source $src to $(basename "$file")"
  else
    log "Already sourcing $src in $(basename "$file")"
  fi
}

# ----- prerequisites -----
if ! command -v curl >/dev/null 2>&1; then
  if command -v dnf >/dev/null 2>&1; then
    log "Installing curl via dnf…"
    $SUDO dnf -y install curl
  else
    warn "curl not found and dnf unavailable — please install curl manually."
  fi
fi

# ----- link config files (only if missing) -----
maybe_link "$SCRIPT_DIR/vim/vimrc"         "$HOME/.vimrc"
maybe_link "$SCRIPT_DIR/vim/ideavimrc"     "$HOME/.ideavimrc"
maybe_link "$SCRIPT_DIR/tmux/tmux.conf"    "$HOME/.tmux.conf"
maybe_link "$SCRIPT_DIR/bash/bashrc_extra" "$HOME/.bashrc_extra"

mkdir -p "$HOME/.config/btop"
maybe_copy "$SCRIPT_DIR/btop/btop.conf" "$HOME/.config/btop/btop.conf"
sanitize_btop_config "$HOME/.config/btop/btop.conf"

# ----- ensure sourcing order in shell rc files -----
ensure_source_in_file "$HOME/.bashrc" "$HOME/.bash_profile"

# ----- install scripts into ~/.local/bin (only if missing) -----
mkdir -p "$HOME/.local/bin"
maybe_link "$SCRIPT_DIR/bash/git-commit-all" "$HOME/.local/bin/git-commit-all"
maybe_link "$SCRIPT_DIR/tmux/tmux-git-badge" "$HOME/.local/bin/tmux-git-badge"
maybe_link "$SCRIPT_DIR/tmux/tmux-ssh-host"  "$HOME/.local/bin/tmux-ssh-host"
maybe_link "$SCRIPT_DIR/tmux/tmux-pane-label" "$HOME/.local/bin/tmux-pane-label"
maybe_link "$SCRIPT_DIR/ssh/install_vm_auto_shutdown.sh" "$HOME/.local/bin/install_vm_auto_shutdown.sh"
if ! is_vm; then
  maybe_link "$SCRIPT_DIR/ssh/vm_start.sh" "$HOME/.local/bin/vm_start.sh"
  maybe_link "$SCRIPT_DIR/ssh/vm_resize.sh" "$HOME/.local/bin/vm_resize.sh"
  maybe_link "$SCRIPT_DIR/ssh/vm_mount.sh" "$HOME/.local/bin/vm_mount.sh"
  maybe_link "$SCRIPT_DIR/ssh/add_ssh_host.sh" "$HOME/.local/bin/add_ssh_host.sh"
else
  log "Running on a VM; skipping install of SSH helper scripts on this machine."
fi

"$SCRIPT_DIR/ssh/install_vm_auto_shutdown.sh" || warn "VM auto-shutdown check did not complete."

# ----- create GOPATH directory ~/.local/state/go (only if missing) -----
mkdir -p "$HOME/.local/state/go"

# ----- install vim-plug (only if missing) -----
if [[ ! -f "$HOME/.vim/autoload/plug.vim" ]]; then
  log "Installing vim-plug…"
  mkdir -p "$HOME/.vim/autoload"
  curl -fLo "$HOME/.vim/autoload/plug.vim" \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
else
  log "vim-plug already present."
fi

# ----- install git completion (only if missing) -----
if [[ ! -f "$HOME/.git-completion.bash" ]]; then
  log "Installing git-completion…"
  curl -fsSL https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash \
    > "$HOME/.git-completion.bash"
else
  log "git-completion already present."
fi

# ======================================================================
# SSH KEY + GIT IDENTITY (run BEFORE the Git defaults section below)
# ======================================================================

# Ensure ssh-keygen exists (openssh-clients on Fedora)
if ! command -v ssh-keygen >/dev/null 2>&1; then
  if command -v dnf >/dev/null 2>&1; then
    log "Installing openssh-clients (for ssh-keygen)…"
    $SUDO dnf -y install openssh-clients
  else
    warn "ssh-keygen not found and dnf unavailable — skipping SSH key creation."
  fi
fi

SSH_DIR="$HOME/.ssh"
SSH_KEY="$SSH_DIR/id_ed25519"
SSH_PUB="$SSH_KEY.pub"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR" || true

# Get name from current git config, or prompt
git_name="$(git config --global --get user.name || true)"
if [[ -z "${git_name:-}" ]]; then
  read -rp "Enter Git user name: " git_name
  while [[ -z "${git_name// }" ]]; do
    read -rp "Name cannot be empty. Enter Git user name: " git_name
  done
fi

# Get email from current git config, or from SSH pubkey comment, or prompt
git_email="$(git config --global --get user.email || true)"
if [[ -z "${git_email:-}" && -f "$SSH_PUB" ]]; then
  # Public key format: <type> <base64> <comment>; comment often holds email
  key_comment="$(awk '{print $3}' "$SSH_PUB" || true)"
  if [[ -n "${key_comment:-}" && "$key_comment" == *"@"* ]]; then
    git_email="$key_comment"
    log "Derived email from SSH key: $git_email"
  fi
fi

if [[ -z "${git_email:-}" ]]; then
  read -rp "Enter email address for Git & SSH key: " git_email
  while [[ -z "${git_email// }" ]]; do
    read -rp "Email cannot be empty. Enter email: " git_email
  done
fi

# Create ed25519 key if missing, unless running inside a VM
if is_vm; then
  log "Running on a VM; skipping SSH key creation on this machine."
elif [[ ! -f "$SSH_KEY" || ! -f "$SSH_PUB" ]]; then
  log "Creating ed25519 SSH key…"
  ssh-keygen -t ed25519 -a 100 -C "$git_email" -f "$SSH_KEY" -N ""
  chmod 600 "$SSH_KEY" || true
  chmod 644 "$SSH_PUB" || true
  log "SSH key created at $SSH_KEY"
else
  log "SSH key already exists: $SSH_KEY"
fi

# ======================================================================
# Git defaults (now we have name/email)
# ======================================================================
git config --global user.name "$git_name"
git config --global user.email "$git_email"
git config --global core.editor "vim"
git config --global push.default "current"
git config --global pull.rebase true
log "Git identity and defaults configured."

log "Done."

# ----- OS detection -----
os="$(uname -s)"
case "$os" in
  Linux)   PLATFORM="linux"; RC_SRC_REL="bashrc_linux"; RC_TARGET="$HOME/.bashrc_linux" ;;
  Darwin)  PLATFORM="mac";   RC_SRC_REL="bashrc_mac";   RC_TARGET="$HOME/.bashrc_mac" ;;
  *) echo "❌ This script can only run on Linux or macOS. Detected: $os"; exit 1 ;;
esac

# ----- link per-OS bashrc -----
RC_SRC_PATH="$SCRIPT_DIR/bash/$RC_SRC_REL"
if [[ ! -f "$RC_SRC_PATH" ]]; then
  warn "Expected $RC_SRC_PATH but it does not exist."
else
  maybe_link "$RC_SRC_PATH" "$RC_TARGET"
fi

# ----- ensure sourcing from the right startup files -----
ensure_source_in_file "$RC_TARGET" "$HOME/.bashrc"
ensure_source_in_file "$HOME/.bashrc_extra" "$HOME/.bashrc"

printf '\n'
printf 'Run `source ~/.bashrc` before proceeding.\n'
printf '\n'
