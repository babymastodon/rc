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

Get Ghostty here: https://ghostty.org (install on the laptop). Kitty configs are also available.

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

After `source ~/.bashrc`, the first thing after SSHing into your VM should be to create a new tmux session using the aliases from `bash/bashrc_extra`:

```bash
# init a new session named "moo"
newmoo

# resume the session
moo
```

## Git shortcuts

After `source ~/.bashrc`, these aliases are available:

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

Recommended: map Right Cmd/Alt to Control, and Caps Lock to Escape.

Linux (keyd):

```bash
cd keyd
./install_keyd.sh
```

macOS (Karabiner-Elements): https://karabiner-elements.pqrs.org
