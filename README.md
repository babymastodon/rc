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

Install Ghostty and link the config:

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

With one host argument, `hoo` attaches through Herdr's remote mode:

```bash
hoo workbox
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

macOS (Karabiner-Elements):

```bash
./karabiner/install_karabiner.sh
```

## Voxtype&nbsp;`💻`

Install Voxtype:

```bash
./voxtype/install_voxtype.sh
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

For motherboard temperatures, fan speeds, and MSI PSU telemetry:

```bash
./sensors/install_sensors.sh
mobo-watch --check
```

`mobo-watch` uses `sensors/sensors.toml` for labels, ordering, hidden sensors,
groups, and PSU display.

On the Gigabyte TRX50 AI TOP, the full temperature/fan set needs the
out-of-tree `it87` DKMS install:

```bash
./sensors/install_gigabyte_trx50_it87_dkms.sh
```

## File Explorer&nbsp;`💻` `🗄️`

Use `yazi` to easily navigate the filesystem and change directories with a TUI.

```bash
./yazi/install_yazi.sh
```

Type the alias `y` to open the file explorer from anywhere.
