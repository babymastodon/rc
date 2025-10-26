#!/bin/bash

echo "Install mpd and rmpc:"
echo
echo "  sudo dnf install mpd"
echo "  cargo install rmpc --locked"
echo "  systemctl --user enable mpd.service"
echo "  systemctl --user start mpd.service"
echo

mkdir -p ~/.config/mpd/
mkdir -p ~/.local/share/mpd/
ln -sf $PWD/mpd.conf ~/.config/mpd/mpd.conf

mkdir -p ~/.config/rmpc/
ln -sf $PWD/config.ron ~/.config/rmpc/config.ron

mkdir -p ~/.local/share/applications/
ln -sf $PWD/rmpc.desktop ~/.local/share/applications/rmpc.desktop

# Install the icon
ICON_URL="https://mierak.github.io/rmpc/favicon.svg"
ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
ICON_PATH="$ICON_DIR/rmpc.svg"
mkdir -p "$ICON_DIR"
curl -fsSL "$ICON_URL" -o "$ICON_PATH"
sed -i 's/#000\b/#89CFF0/Ig' "$ICON_PATH"
sed -i 's/#fff\b/#89CFF0/Ig' "$ICON_PATH"
gtk-update-icon-cache "$HOME/.local/share/icons/hicolor" -f 2>/dev/null || true
echo "✅ Installed icon at $ICON_DIR/rmpc.svg"

update-desktop-database ~/.local/share/applications

