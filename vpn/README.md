# WireGuard and SSH

Sets up a WireGuard tunnel to your VPN server that you turn on and off from the desktop's VPN
menu, and an SSH server that is reachable over the VPN and trusted networks only. Run the scripts
from the rc checkout; each is safe to rerun and only changes what differs. Shared values (tunnel
name, VPN subnet, home network) live in `vpn/settings`.

| | Windows | Fedora (GNOME) | macOS (13 or later) |
|---|---|---|---|
| Install | `.\vpn\windows-install.ps1` | `bash vpn/linux-install.sh` | `bash vpn/mac-install.sh` |
| Enroll | `.\vpn\windows-connect.ps1` | `bash vpn/linux-connect.sh` | `bash vpn/mac-connect.sh` |
| Add SSH keys | `.\vpn\windows-add-key.ps1` | `bash vpn/add-key.sh` | `bash vpn/add-key.sh` |
| VPN on/off | WireGuard tray icon | VPN in Quick Settings | WireGuard menu bar icon |

## Enroll

Create a config for the computer on the VPN server:

```sh
ssh <server>
cd ~/code/rc
sudo bash vpn/add-client.sh
```

Then run the enroll script for the computer and give it the config `add-client.sh` printed, from
`[Interface]` through `PersistentKeepalive`. The config contains a private key, so never save it
in this repo. Run it again to replace the config.

`add-client.sh` routes the subnet named by the `# Subnetwork:` line in the server's WireGuard
config, or all traffic when that line is missing. Unless the config already routes all traffic,
the enroll scripts also route the home network through the VPN, so home machines are reachable
from anywhere. The install scripts list the routes the VPN carries and say when the home network
is missing.

## Windows

The scripts ask for administrator rights and continue in a new Windows Terminal window. Install
sets up WireGuard, its tray app and the OpenSSH server; a changed `sshd_config` is backed up next
to the original. Enroll asks you to copy the config, reads it from the clipboard, clears the
clipboard and stores the config in the WireGuard app, encrypted.

SSH is open on Private networks, which includes the VPN and any network you mark Private in
Settings > Network & internet, and blocked on Public and Domain networks. Keys live in
`C:\ProgramData\ssh\administrators_authorized_keys`. The tray icon appears for administrator
accounts and the tunnel keeps its on/off state across restarts. Rename the computer in Settings >
System > About > Rename this PC.

## Fedora

The scripts ask for your password through `sudo`. Install sets up NetworkManager, firewalld and
the OpenSSH server. Enroll asks you to paste the config into the terminal and imports it into
NetworkManager, which keeps it readable only by root. The tunnel comes back on at every boot.

SSH is open in the firewalld zone `home`, which holds the VPN, and closed in the default zone
that every other network uses. To trust your home network, run
`sudo nmcli connection modify '<network>' connection.zone home` and reconnect to it. Keys live in
`~/.ssh/authorized_keys`. Rename the computer in Settings > System > About.

## macOS

Install WireGuard from the [Mac App Store](https://apps.apple.com/app/wireguard/id1451685025)
first; the install script reminds you when it is missing. Install turns on Remote Login and adds
firewall (pf) rules, loaded at every boot, that allow SSH only from the VPN and the home network.
Enroll asks you to paste the config into the terminal and opens it as a configuration profile;
install the profile in System Settings > General > Device Management, then press Enter.

macOS has no per-network trust, so any network using the home network's address range counts as
home. Keys live in `~/.ssh/authorized_keys`. Rename the computer in System Settings > General >
Sharing > Local hostname.

## SSH keys

To let a device log in, print its public key on that device with `cat ~/.ssh/id_ed25519.pub`.
Then run the add-key script on this computer and paste it.

To trust the same devices as another machine, give its SSH login instead:

```sh
bash vpn/add-key.sh <user>@<server>
```

```powershell
.\vpn\windows-add-key.ps1 <user>@<server>
```

This saves `<server>` as an SSH alias for that login and logs in. If key login is refused, it asks
for the password and installs this computer's key there, labeled `<user>@<computer name>`. If this
computer has no key yet, it creates one with a passphrase and adds it to ssh-agent, so you type
the passphrase only once. While this computer is on the home network, it also adds the computer's
name as an alias in that machine's `~/.ssh/config`, pointing at its home-network address, and
warns if the firewall here still treats that network as untrusted. It then copies that machine's
`~/.ssh/authorized_keys` here, except this computer's own key and keys restricted with options
such as `command=`. With an existing alias, give just the alias.

Delete a line from the keys file to revoke a device.
