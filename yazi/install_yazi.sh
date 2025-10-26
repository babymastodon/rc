#!/bin/bash

echo "Install yazi:"
echo
echo "  cargo install yazi-build"
echo

mkdir -p ~/.config/yazi/
ln -sf $PWD/yazi.toml ~/.config/yazi/yazi.toml

mkdir -p ~/.local/share/applications/
ln -sf $PWD/yazi.desktop ~/.local/share/applications/yazi.desktop

# Install Icon
d="$HOME/.local/share/icons/hicolor/256x256/apps"
t="$(mktemp)"
mkdir -p "$d"
curl -fsSL https://yazi-rs.github.io/webp/logo.webp -o "$t"
magick "$t" -resize 256x256 "$d/yazi.png"
rm -f "$t"
gtk-update-icon-cache "$HOME/.local/share/icons/hicolor" -f 2>/dev/null || true
echo "✅ Installed: $d/yazi.png (use Icon=yazi in your .desktop)"

update-desktop-database ~/.local/share/applications

