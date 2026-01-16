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

Get Ghostty here: https://ghostty.org (install on the laptop). It's a GPU-accelerated, customizable terminal. Kitty configs are also available.

After install, link the config from this repo:

```bash
cd ghostty
./install_ghostty.sh
```

## Vim

Install coc.nvim tooling for Vim (autocompleter support for multiple languages):

```bash
cd vim
./install_coc.sh
```

Key shortcuts:

```text
move: hjkl
move a lot: Shift-hjkl
new tab: Ctrl-t
close tab: :q
open current directory: Ctrl-d
go to definition: gd
undo go to definition: Ctrl-o
save: :w
copy: \\c
```

If you want plugins, open Vim and run:

```vim
:PlugInstall
```

## tmux sessions

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

## Codex

Install the Codex CLI:

```bash
npm i -g @openai/codex
```

Log in with ChatGPT. If the login prompt opens in a browser on the VM, SSH tunnel the port to your laptop:

```bash
ssh -L 1455:localhost:1455 you@your-vm
```

Then open the localhost URL that the login prompt prints in your laptop browser.
