// extension.js — GNOME Shell 49
//
// Dependencies (present in GS 49):
//  - Meta (gi://Meta): window types, keybinding flags
//  - Shell (gi://Shell): ActionMode flags for keybindings
//  - Extension (extensions/extension.js): modern base class with getSettings()
//  - Main (ui/main.js): access to WM keybinding API and notify()
//
// No UI elements here, so we do NOT import St or Clutter.

import Meta from 'gi://Meta';
import Shell from 'gi://Shell';

import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const KEY_NAME = 'hotkey'; // matches your schema key (type 'as')

function moveAllToPrimary() {
  const primary = global.display.get_primary_monitor(); // integer index
  let moved = 0;

  for (const actor of global.get_window_actors()) {
    const w = actor.meta_window;
    if (!w) continue;

    // Only move normal app windows; skip minimized/hidden/transients/system
    if (w.window_type !== Meta.WindowType.NORMAL) continue;
    if (w.skip_taskbar || w.minimized || (w.is_hidden && w.is_hidden())) continue;

    try { w.move_to_monitor(primary); moved++; } catch (_e) { /* ignore */ }
  }

  Main.notify('Bring to Primary', `Moved ${moved} windows`);
}

export default class BringToPrimaryExtension extends Extension {
  enable() {
    // GS 49: Extension.getSettings() reads the schema named in metadata.json
    this._settings = this.getSettings();

    // Remove any prior binding (hot-reload safety)
    if (Main.wm.removeKeybinding) {
      Main.wm.removeKeybinding(KEY_NAME);
    }

    // Register the keybinding in NORMAL and OVERVIEW modes
    Main.wm.addKeybinding(
      KEY_NAME,
      this._settings,
      Meta.KeyBindingFlags.NONE,
      Shell.ActionMode.NORMAL | Shell.ActionMode.OVERVIEW,
      () => moveAllToPrimary()
    );
  }

  disable() {
    if (Main.wm.removeKeybinding) {
      Main.wm.removeKeybinding(KEY_NAME);
    }
    this._settings = null;
  }
}

