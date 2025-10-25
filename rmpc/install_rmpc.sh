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
