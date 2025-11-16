#!/bin/bash
# ~/.local/bin/kitty-theme-watcher.sh
# Watches GNOME color-scheme and switches all Kitty instances under /tmp/kitty-*

LIGHT_THEME="$HOME/.config/kitty/themes/MonokaiCustomLight.conf"
DARK_THEME="$HOME/.config/kitty/themes/MonokaiCustom.conf"

apply_theme() {
  local mode="$1"
  local theme="$LIGHT_THEME"
  [[ "$mode" == *dark* ]] && theme="$DARK_THEME"

  for sock in /tmp/kitty-*; do
    kitty @ --to "unix:$sock" set-colors "$theme" 2>/dev/null
  done
}

# 1) Apply once using current setting
current=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)
apply_theme "$current"

# 2) Watch for changes and re-apply
gsettings monitor org.gnome.desktop.interface color-scheme | while read -r _; do
  current=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)
  apply_theme "$current"
done

