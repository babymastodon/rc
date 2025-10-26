#!/bin/bash

echo "Install yazi:"
echo
echo "  cargo install yazi-build"
echo

mkdir -p ~/.config/yazi/
ln -sf $PWD/yazi.toml ~/.config/yazi/yazi.toml

mkdir -p ~/.local/share/applications/
ln -sf $PWD/yazi.desktop ~/.local/share/applications/yazi.desktop
chmod +x ~/.local/share/applications/yazi.desktop
update-desktop-database ~/.local/share/applications
