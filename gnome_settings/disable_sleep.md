# Surface Laptop 5 (Fedora) — Disable Suspend and Map Lid/Power to Lock + Blank

These instructions configure Fedora (GNOME/Wayland) on Surface Laptop 5 to **disable modern suspend (s2idle)** and instead **lock + blank the screen** when closing the lid or pressing the power button.

---

## 1. Stop logind from suspending
Edit `/etc/systemd/logind.conf`:

```ini
[Login]
HandleLidSwitch=ignore
HandleLidSwitchDocked=ignore
HandleLidSwitchExternalPower=ignore
HandlePowerKey=ignore
```

Apply changes:

```bash
sudo systemctl restart systemd-logind
```

---

## 2. Script to lock + blank

Create `/usr/local/bin/lock-and-blank-root`:

```bash
#!/usr/bin/env bash
# Lock and blank for the active graphical user session (GNOME Wayland/Xorg)

SESSION_ID="$(loginctl list-sessions --no-legend | awk '($4=="wayland" || $4=="x11") && $5=="seat0" {print $1; exit}')"
[ -z "$SESSION_ID" ] && SESSION_ID="$(loginctl list-sessions --no-legend | awk '{print $1; exit}')"

USER_ID="$(loginctl show-session "$SESSION_ID" -p User --value 2>/dev/null)"
[ -z "$USER_ID" ] && exit 0
USER_NAME="$(getent passwd "$USER_ID" | cut -d: -f1)"
RUNTIME_DIR="/run/user/$USER_ID"

# Lock
loginctl lock-session "$SESSION_ID" 2>/dev/null

# Wayland: Mutter's D-Bus TurnOffDisplays
if [ -S "$RUNTIME_DIR/bus" ]; then
  export DBUS_SESSION_BUS_ADDRESS="unix:path=$RUNTIME_DIR/bus"
  /usr/bin/runuser -u "$USER_NAME" -- \
    gdbus call --session \
      --dest org.gnome.Mutter.DisplayConfig \
      --object-path /org/gnome/Mutter/DisplayConfig \
      --method org.gnome.Mutter.DisplayConfig.TurnOffDisplays \
      >/dev/null 2>&1 && exit 0
fi

# Xorg fallback: DPMS off
DISPLAY=":0"
XAUTH="$(find "/home/$USER_NAME" -maxdepth 2 -name .Xauthority 2>/dev/null | head -n1)"
[ -n "$XAUTH" ] && export XAUTHORITY="$XAUTH"
export DISPLAY
/usr/bin/runuser -u "$USER_NAME" -- xset dpms force off >/dev/null 2>&1 || true
```

Make executable:

```bash
sudo chmod +x /usr/local/bin/lock-and-blank-root
```

---

## 3. ACPI rules

Install and enable `acpid`:

```bash
sudo dnf install -y acpid
sudo systemctl enable --now acpid
```

### Lid close → lock + blank
Create `/etc/acpi/events/lid`:

```text
event=button/lid.*
action=/usr/local/bin/lock-and-blank-root
```

### Power button → lock + blank
Create `/etc/acpi/events/powerbtn`:

```text
event=button/power.*
action=/usr/local/bin/lock-and-blank-root
```

Reload:

```bash
sudo systemctl restart acpid
```

---

## 4. Test

- Manually run:
  ```bash
  /usr/local/bin/lock-and-blank-root
  ```
  → screen should lock + blank.

- Watch ACPI events:
  ```bash
  sudo journalctl -u acpid -f
  ```

- Confirm logind ignores lid/power:
  ```bash
  loginctl show-session $(loginctl | awk '/seat/{print $1; exit}') -p HandleLidSwitch -p HandlePowerKey
  ```

---

## 5. Cleanup (optional)

Remove unused configs from earlier attempts:

```bash
# Old user units/scripts
systemctl --user disable --now lid-close.service 2>/dev/null || true
rm -f ~/.config/systemd/user/lid-close.service
rm -rf ~/.config/systemd/user/handle-lid-switch.target.wants
rm -f ~/.local/bin/lock-and-blank

# Remove nosuspend drop-in (if you want suspend back)
sudo rm -f /etc/systemd/sleep.conf.d/nosuspend.conf
sudo rmdir --ignore-fail-on-non-empty /etc/systemd/sleep.conf.d
```

---

## Notes

- This uses **GNOME Mutter’s built-in D-Bus API** (`TurnOffDisplays`) to blank screens instantly.
- Works on **Wayland** (preferred). Falls back to `xset dpms force off` on Xorg.
- Ensures **no suspend** happens, only lock + blank.
- Power button and lid both behave consistently.

