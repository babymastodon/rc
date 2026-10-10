#!/usr/bin/env bash
# Integration checks that install real packages in a disposable VM.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if ! systemd-detect-virt --vm --quiet || ! command -v pacman >/dev/null 2>&1 || [[ $EUID -eq 0 ]]; then
  printf 'Run as a test user with sudo in a disposable Arch or Omarchy VM.\n' >&2
  exit 1
fi

sudo -n true
export PATH="$HOME/.local/bin:$PATH"
export XDG_CURRENT_DESKTOP=Hyprland
export DESKTOP_SESSION=hyprland

# Avoid the interactive identity and auto-shutdown prompts in the test VM.
git config --global --get user.name >/dev/null || git config --global user.name 'RC VM Test'
git config --global --get user.email >/dev/null || git config --global user.email tester@example.invalid
sudo touch /etc/systemd/system/rc-vm-auto-shutdown.disabled

declare -A existing_configs=()
for app in alacritty ghostty kitty; do
  case "$app" in
    alacritty) config="$HOME/.config/alacritty/alacritty.toml" ;;
    ghostty) config="$HOME/.config/ghostty/config" ;;
    kitty) config="$HOME/.config/kitty/kitty.conf" ;;
  esac
  if [[ -f "$config" && ! -L "$config" ]]; then
    existing_configs["$config"]="$(sha256sum "$config")"
  fi
done

installers=(
  install.sh
  vim/install_vim.sh
  tmux/install_tmux.sh
  btop/install_btop.sh
  ghostty/install_ghostty.sh
  kitty/install_kitty.sh
  alacritty/install_alacritty.sh
  yazi/install_yazi.sh
  rmpc/install_rmpc.sh
  keyd/install_keyd.sh
  ssh/install_sshfs.sh
  gnome-shell/install_ddcutil.sh
  gnome-shell/install_default_terminal.sh
  keyd/install_shortcuts.sh
  gnome-shell/install_extensions.sh
)

for pass in 1 2; do
  for installer in "${installers[@]}"; do
    printf '\nTesting %s (pass %s)\n' "$installer" "$pass"
    bash "$REPO_ROOT/$installer"
  done
done

# Exercise the real dependency installation portions of the account/audio
# installers while leaving their interactive or hardware-dependent main flows out.
dependency_scripts=()
cleanup() { rm -f "${dependency_scripts[@]}"; }
trap cleanup EXIT
for pass in 1 2; do
  voice_test="$(mktemp "$REPO_ROOT/voxtype/.deps-test.XXXXXX.sh")"
  dropbox_test="$(mktemp "$REPO_ROOT/dropbox/.deps-test.XXXXXX.sh")"
  dependency_scripts+=("$voice_test" "$dropbox_test")
  awk '/^preflight$/ { exit } { print }' "$REPO_ROOT/voxtype/install_voxtype_linux.sh" > "$voice_test"
  printf '\ninstall_system_deps\nrequire_prereqs\n' >> "$voice_test"
  bash "$voice_test"
  awk '/^log "=== Dropbox headless/ { exit } { print }' "$REPO_ROOT/dropbox/install.sh" > "$dropbox_test"
  bash "$dropbox_test"
done

for config in "${!existing_configs[@]}"; do
  [[ "$(sha256sum "$config")" == "${existing_configs[$config]}" ]]
done

for command in vim tmux btop ghostty kitty alacritty yazi rmpc mpd keyd sshfs; do
  command -v "$command" >/dev/null
done
[[ -L "$HOME/.vimrc" && -L "$HOME/.config/yazi/yazi.toml" ]]
[[ -s "$HOME/.config/alacritty/current-theme.toml" ]]
[[ ! -e "$HOME/.config/systemd/user/alacritty-theme-watcher.service" ]]
[[ "$(readlink /etc/keyd/default.conf)" == "$REPO_ROOT/keyd/default.conf" ]]
[[ "$(grep -Fc "source $HOME/.bashrc_extra" "$HOME/.bashrc")" == 1 ]]
systemctl --user is-active --quiet mpd.service
sudo systemctl is-active --quiet keyd.service
fc-match 'Hack Nerd Font' | grep -q Hack

printf '\nArch/Hyprland installer integration checks passed.\n'
