# SSH VM Launching

`./install.sh` installs these on non-VM machines:

- `add_ssh_host.sh`
- `vm_start.sh`
- `vm_mount.sh`
- `vm`, a shell alias for `vm_start.sh`
- `vmfs`, a shell alias for `vm_mount.sh`

## AWS Prerequisites

If you are connecting to an AWS-hosted VM, install the AWS CLI and AWS Session
Manager plugin first.

Before first use, configure AWS SSO:

```bash
aws configure sso
```

When prompted for `SSO session name`, enter `user`.

Use the SSO start URL and SSO region required by your company. Get those from
your company admin or internal onboarding docs. The AWS account and role are
also company-specific.

After that, log in when needed with:

```bash
aws sso login
```

## Prepare The VM User

Before `vm` can log in, the VM needs a Linux user for you and your public key installed for that user.

These steps assume you can reach the machine through the cloud provider's browser-based terminal or serial console in AWS or GCP.

### 1. Copy Your Local Public Key

If you ran `./install.sh` on your laptop, your SSH key should already exist.
Print the public key so you can paste it into the VM:

```bash
cat ~/.ssh/id_ed25519.pub
```

If that file is missing, run `./install.sh` first.

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

Still on the VM, run:

```bash
sudo install -d -m 700 -o "$devuser" -g "$devuser" "/home/$devuser/.ssh"
read -r -p "Paste your public key, then press Enter: " pubkey
printf '%s\n' "$pubkey" | sudo tee "/home/$devuser/.ssh/authorized_keys" >/dev/null
sudo chown "$devuser:$devuser" "/home/$devuser/.ssh/authorized_keys"
sudo chmod 600 "/home/$devuser/.ssh/authorized_keys"
```

Paste the contents of your local `~/.ssh/id_ed25519.pub`, then press `Enter`.

### 5. Create The SSH Alias

Back on your laptop:

```bash
vmadd
```

This opens a short wizard and writes the SSH alias to `~/.ssh/config`.

### 6. Connect

```bash
vm <alias>
```

`<alias>` is the SSH alias name you selected in step 6.

To forward ports while connecting, add them after the alias:

```bash
vm <alias> 8080 3000
```

This forwards `localhost:8080` and `localhost:3000` on your laptop to the same
ports on the VM.

## Mount The VM Filesystem

Install `sshfs` on your laptop:

```bash
./ssh/install_sshfs.sh
```

Then mount the VM home directory at `~/vmfs/<alias>`:

```bash
vmfs <alias>
```

To unmount it later:

```bash
vmfs <alias> umount
```

## VM Auto-Shutdown

When `./install.sh` runs on a VM, it checks whether daily auto-shutdown is configured.

To reconfigure that timer later, run:

```bash
~/.local/bin/install_vm_auto_shutdown.sh edit
```

Edit mode interactively re-prompts for the shutdown timezone and hour, or lets
you disable the managed timer.
