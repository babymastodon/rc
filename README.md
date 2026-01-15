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

Install Ghostty with your package manager, then link the config in this repo:

```bash
# Fedora
sudo dnf install -y ghostty

# Debian/Ubuntu
sudo apt-get install -y ghostty

# macOS (Homebrew)
brew install --cask ghostty

./ghostty/install_ghostty.sh
```

## Vim

Install Vim, then use the repo's config:

```bash
# Fedora
sudo dnf install -y vim

# Debian/Ubuntu
sudo apt-get install -y vim

# macOS (Homebrew)
brew install vim

./install.sh
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
