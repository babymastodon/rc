# SSH VM Launching

`./install.sh` installs these on non-VM machines:

- `add_ssh_host.sh`
- `vm_start.sh`
- `vm_mount.sh`
- `vm`, a shell alias for `vm_start.sh`
- `vmfs`, a shell alias for `vm_mount.sh`

## Prepare The VM User

Before `vm` can log in, the VM needs a Linux user for you and your public key installed for that user.

These steps assume you can reach the machine through the cloud provider's browser-based terminal or serial console in AWS or GCP.

### 1. Generate A Local SSH Key

If you do not already have one:

```bash
ssh-keygen -t ed25519 -a 100 -C "you@example.com" -f ~/.ssh/id_ed25519
```

Print the public key so you can paste it into the VM:

```bash
cat ~/.ssh/id_ed25519.pub
```

### 2. Create Your Linux User

In the cloud web terminal on the VM, set the username you want to use and create the user:

```bash
devuser=yourusername
sudo useradd -m -s /bin/bash "$devuser"
```

### 3. Give Yourself Sudo Access

Create an idempotent sudoers drop-in:

```bash
echo "$devuser ALL=(ALL) NOPASSWD: ALL" | sudo tee "/etc/sudoers.d/$devuser" >/dev/null
sudo chmod 440 "/etc/sudoers.d/$devuser"
sudo visudo -cf "/etc/sudoers.d/$devuser"
```

### 4. Install Your Public Key

Still on the VM:

```bash
sudo mkdir -p "/home/$devuser/.ssh"
sudo chmod 700 "/home/$devuser/.ssh"
sudo sh -c "cat >> /home/$devuser/.ssh/authorized_keys"
sudo chmod 600 "/home/$devuser/.ssh/authorized_keys"
sudo chown -R "$devuser:$devuser" "/home/$devuser/.ssh"
```

After running the `cat >> ...authorized_keys` command, paste the contents of your local `~/.ssh/id_ed25519.pub`, then press `Ctrl-D`.

### 6. Create The SSH Alias

Back on your laptop:

```bash
vmadd
```

This opens a short wizard and writes the SSH alias to `~/.ssh/config`.

### 7. Connect

```bash
vm <alias>
```

`<alias>` is the SSH alias name you selected in step 6.
