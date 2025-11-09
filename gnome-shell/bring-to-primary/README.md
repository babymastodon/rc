# Bring All Windows to Primary (GNOME Shell 49)

Move all normal application windows to your **primary monitor** with a single hotkey.  
Handy after docking/undocking or display sleep when GNOME scatters windows.

- **Hotkey:** `Super + E` (configurable)
- **Scope:** moves *normal, visible* app windows (skips minimized/hidden/transient/system)
- **Target:** GNOME Shell **49** (Wayland and Xorg)

---

## Requirements
- GNOME Shell **49.x**
- Access to `~/.local/share/gnome-shell/extensions/`
- `glib2` tools for schema compilation (`glib-compile-schemas`)
- (Wayland) ability to log out/in to reload Shell

---

## Install (from source)

```bash
# 1) Copy into local extensions
EXT=bring-to-primary@local
mkdir -p ~/.local/share/gnome-shell/extensions/$EXT
cp -r * ~/.local/share/gnome-shell/extensions/$EXT/

# 2) Compile the settings schema
glib-compile-schemas ~/.local/share/gnome-shell/extensions/$EXT/schemas

# 3) Pack & install (helps GNOME pick it up cleanly)
cd ~/.local/share/gnome-shell/extensions/$EXT
gnome-extensions pack . --force
gnome-extensions install --force $EXT.shell-extension.zip

# 4) Restart GNOME Shell and enable
# Wayland: log out → log in
# Xorg:    Alt+F2, type r, Enter
gnome-extensions enable bring-to-primary@local
````

Verify:

```bash
gnome-extensions list | grep bring-to-primary
```

---

## Use

Press **`Super + E`**.
A notification shows how many windows were moved.

Change the hotkey:

```bash
gsettings get org.gnome.shell.extensions.bring-to-primary hotkey
gsettings set org.gnome.shell.extensions.bring-to-primary hotkey "['<Super><Shift>P']"
```

---

## Uninstall / disable

```bash
gnome-extensions disable bring-to-primary@local
rm -rf ~/.local/share/gnome-shell/extensions/bring-to-primary@local
```

---

## Troubleshooting

**“Extension … does not exist” when enabling**

* Ensure folder name matches UUID:
  `~/.local/share/gnome-shell/extensions/bring-to-primary@local`
* Re-pack & re-install, then log out/in on Wayland.

**Hotkey does nothing**

* Recompile schemas:
  `glib-compile-schemas ~/.local/share/gnome-shell/extensions/bring-to-primary@local/schemas`
* Confirm the key is set:
  `gsettings get org.gnome.shell.extensions.bring-to-primary hotkey`
* Check logs:
  `journalctl --user -b -g gnome-shell | tail -n 100`

**Windows still spread to other monitors later**

* That’s GNOME/Mutter reacting to display hotplug/sleep. Re-press the hotkey to gather, or pair this with a “window restore” extension.

---

## Notes & compatibility

* Uses the GNOME 49 ESModule API (`extensions/extension.js`) and `this.getSettings()`.
* Uses `Meta.Window.move_to_monitor(primary)` and `global.display.get_primary_monitor()`.
  These work on 49; monitor APIs may evolve in future GNOME releases.

---

## Files

```
bring-to-primary@local/
├─ extension.js
├─ metadata.json
└─ schemas/
   └─ org.gnome.shell.extensions.bring-to-primary.gschema.xml
```

---

## License

MIT
