#!/usr/bin/env bash
set -euo pipefail

# ----- helpers -----
log()   { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }
need_sudo() { if [[ $EUID -ne 0 ]]; then echo "sudo"; fi; }
SUDO="$(need_sudo || true)"

maybe_link() {
  local src="$1" dest="$2"
  if [[ -e "$dest" || -L "$dest" ]]; then
    log "Exists, not linking: $dest"
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

ensure_line_in_file() {
  local line="$1" file="$2"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if grep -qxF "$line" "$file"; then
    log "Line already present in $(basename "$file")"
  else
    printf "%s\n" "$line" >> "$file"
    log "Appended to $(basename "$file"): $line"
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
maybe_link "$PWD/vimrc"             "$HOME/.vimrc"
maybe_link "$PWD/ideavimrc"         "$HOME/.ideavimrc"
maybe_link "$PWD/tmux.conf"         "$HOME/.tmux.conf"
maybe_link "$PWD/bashrc_extra"      "$HOME/.bashrc_extra"
maybe_link "$PWD/gitignore_global"  "$HOME/.gitignore_global"

mkdir -p "$HOME/.config/btop"
maybe_copy "$PWD/btop.conf" "$HOME/.config/btop/btop.conf"

mkdir -p "$HOME/.config/ghostty"
maybe_link "$PWD/ghostty.config" "$HOME/.config/ghostty/config"

# ----- ensure sourcing order in shell rc files -----
ensure_line_in_file "source ~/.bashrc_extra" "$HOME/.bashrc"
ensure_line_in_file "source ~/.bashrc"       "$HOME/.bash_profile"

# Source for current session (best-effort, non-interactive safe)
if [[ -f "$HOME/.bashrc_extra" ]]; then
  set +e
  # shellcheck disable=SC1090
  source "$HOME/.bashrc_extra" || true
  set -e
fi

# ----- install scripts into ~/bin (only if missing) -----
mkdir -p "$HOME/bin"
maybe_link "$PWD/git-commit-all" "$HOME/bin/git-commit-all"
maybe_link "$PWD/tmux-git-badge" "$HOME/bin/tmux-git-badge"
maybe_link "$PWD/tmux-ssh-host"  "$HOME/bin/tmux-ssh-host"

# ----- install config files into ~/etc -----
mkdir -p "$HOME/etc"

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

# Create ed25519 key if missing
if [[ ! -f "$SSH_KEY" || ! -f "$SSH_PUB" ]]; then
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
git config --global user.name "Zachary Drach"
git config --global user.email "$git_email"
git config --global core.editor "vim"
git config --global core.excludesfile "$HOME/.gitignore_global"
git config --global push.default "current"
git config --global pull.rebase true
log "Git identity and defaults configured."

log "Done."

