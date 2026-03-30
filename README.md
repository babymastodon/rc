# rc

Personal dotfiles and setup scripts for a desktop environment that uses tmux for window management, Vim for code editing, and works well over SSH. Supports macOS and Linux.

## Getting started

1) Install/link the files in this repo:

```bash
./install.sh
```

2) Reload your shell so the aliases/functions are available:

```bash
source ~/.bashrc
```

## Ghostty

Get Ghostty here: https://ghostty.org (install on the laptop). It's a GPU-accelerated terminal that matches your OS light/dark theme. Kitty configs are also available.

After install, link the config from this repo:

```bash
cd ghostty
./install_ghostty.sh
```

## Vim

Install Vim and the development tools for Rust, Go, Node, and Python:

```bash
cd vim
./install_vim.sh
./install_languages.sh
```

If you want plugins, open `vim` and run:

```vim
:PlugInstall
```

Key shortcuts:

```text
move: hjkl
move a lot: Shift-hjkl
new tab: Ctrl-t
close tab: :q
open current directory: Ctrl-e
go to definition: gd
undo go to definition: Ctrl-o
save: :w
copy: \\c
```

## tmux sessions

Install tmux:

```bash
cd tmux
./install_tmux.sh
```

The install script sets up these aliases to start or resume a tmux session:

```bash
# init a new session named "moo"
newmoo

# resume the session
moo
```

Key shortcuts:

```text
move between windows: Shift-Left/Right
new window: Ctrl-b c
close window: Ctrl-d
```

## Git shortcuts

The install script sets up these aliases:

```bash
g='git'
ga='git add .'
st='git status && git diff --stat'
gd='git diff'
gs='git -c color.status=always status -s && ...'
cm='git-commit-all'
pl='git pull'
ph='git push --force-with-lease'
mg='git fetch && git merge origin/master --no-edit'
br='git log --graph --oneline --decorate --all'
```

## Keyboard remaps

Recommended to reduce wrist strain: map Right Cmd/Alt to Control, and Caps Lock to Escape.

Linux (keyd):

```bash
cd keyd
./install_keyd.sh
```

macOS (Karabiner-Elements): https://karabiner-elements.pqrs.org

```bash
cd karabiner
./install_karabiner.sh
```

## Codex

Install and link the Codex config from this repo:

```bash
cd codex
./install_codex.sh
```

Then run `codex` and log in with ChatGPT, not an API key.

## SSH

Use `vmadd` to add a VM alias, then `vm <alias>` to start and connect:

```bash
vmadd
vm devserver
```

Use `vmresize <alias>` to change a VM size within the same instance family.

Setup details and config examples are in `ssh/README.md`.

To mount a VM home directory on macOS, install MacFUSE and `sshfs`:
https://macfuse.github.io/

Then use `vm <alias>` to mount:

```bash
vmfs devserver
```

## System Monitor

Use `btop` to monitor resource usage with a terminal UI.

```bash
cd btop
./install_btop.sh
```

If the colors look odd, open the btop options menu and make sure the `TTY` theme is selected.

## File Explorer

Use `yazi` to easily navigate the filesystem and change directories with a TUI.

```bash
cd yazi
./install_yazi.sh
```

Type the alias `y` to open the file explorer from anywhere.
