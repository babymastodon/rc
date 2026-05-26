# rc

Personal dotfiles and setup scripts for a desktop environment that uses Herdr for persistent sessions, Vim for code editing, and works well over SSH. Supports macOS and Linux.

Where to run each section: `💻` laptop, `🗄️` server

## Getting started&nbsp;`💻` `🗄️`

1) Clone the repo:

```bash
mkdir -p ~/code
cd ~/code
git clone git@github.com:babymastodon/rc.git
cd rc
```

2) Install/link the files in this repo:

```bash
./install.sh
```

3) If you are on Mac OS, set your default shell to Bash and restart your shell:

```bash
./bash/install_bash_mac.sh
```

4) Reload your shell so the aliases/functions are available:

```bash
source ~/.bashrc
```

## Ghostty&nbsp;`💻`

Get Ghostty here: https://ghostty.org (install on the laptop). It's a GPU-accelerated terminal that matches your OS light/dark theme. Kitty configs are also available.

After install, link the config from this repo:

```bash
./ghostty/install_ghostty.sh
```

## Vim&nbsp;`💻` `🗄️`

Install Vim:

```bash
./vim/install_vim.sh
```

Install the shared runtimes, CLI tools, and language servers via `mise`:

```bash
./mise/install_mise.sh
source ~/.bashrc
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
open current directory: Ctrl-f
fuzzy find file: Ctrl-p
go to definition: gd
undo go to definition: Ctrl-o
save: :w
copy: \\c
```

## herdr session&nbsp;`💻` `🗄️`

Install herdr:

```bash
./herdr/install_herdr.sh
```

The shell setup adds `hoo` as a shortcut for `herdr`:

```bash
hoo
```

It is very convenient to run Herdr on a remote VM, since agents can keep working in the background after you disconnect.

## Git shortcuts&nbsp;`💻` `🗄️`

The install script sets up these aliases:

```bash
g='git'
ga='git add .'
st='git status && git diff --stat'
gd='git diff origin/master'
gs='git -c color.status=always status -s && ...'
cm='git-commit-all'
pl='git pull'
ph='git push --force-with-lease'
mg='git fetch && git merge origin/master --no-edit'
br='git log --graph --oneline --decorate --all'
lg='lazygit'
```

## Keyboard remaps&nbsp;`💻`

Recommended to reduce wrist strain: map Right Cmd/Alt to Control, and Caps Lock to Escape.

Linux (keyd):

```bash
./keyd/install_keyd.sh
```

The Copilot key is mapped to Voxtype push-to-talk on Linux. The Voxtype config targets GNOME typing through `ydotool`. Install the home-scoped Voxtype Cohere CPU setup and link this repo's config:

```bash
./voxtype/install_voxtype.sh
```

macOS (Karabiner-Elements): https://karabiner-elements.pqrs.org

```bash
./karabiner/install_karabiner.sh
```

## Codex&nbsp;`💻` `🗄️`

Install and link the Codex config from this repo:

```bash
./codex/install_codex.sh
```

Then run `codex` and log in with ChatGPT, not an API key. When logging in on a remote VM, port-forward the Codex login port so the browser callback can reach the VM.

## SSH&nbsp;`💻`

Read [`ssh/README.md`](ssh/README.md) first.
It covers how to install your SSH public key on the VM before first use.

After that, use `vmadd` to add a VM alias, then `vm <alias>` to start and connect:

```bash
vmadd
vm devserver
```

You can also forward ports while connecting:

```bash
vm devserver 8080 3000
```

Use `vmresize <alias>` to change a VM size within the same instance family.

To mount a VM home directory on Linux or macOS, install `sshfs` first:

```bash
./ssh/install_sshfs.sh
```

Then use `vmfs <alias>` to mount:

```bash
vmfs devserver
```

To unmount it again:

```bash
vmfs devserver umount
```

## System Monitor&nbsp;`💻` `🗄️`

Use `btop` to monitor resource usage with a terminal UI.

```bash
./btop/install_btop.sh
```

If the colors look odd, open the btop options menu and make sure the `TTY` theme is selected.

## File Explorer&nbsp;`💻` `🗄️`

Use `yazi` to easily navigate the filesystem and change directories with a TUI.

```bash
./yazi/install_yazi.sh
```

Type the alias `y` to open the file explorer from anywhere.
