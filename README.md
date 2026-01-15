# rc

Personal dotfiles and setup scripts.

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

Get Ghostty here: https://ghostty.org

After install, link the config from this repo:

```bash
cd ghostty
./install_ghostty.sh
```

## Vim

Install coc.nvim tooling for Vim:

```bash
cd vim
./install_coc.sh
```

If you want plugins, open Vim and run:

```vim
:PlugInstall
```

## tmux sessions

After `source ~/.bashrc`, use the aliases from `bash/bashrc_extra`:

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
