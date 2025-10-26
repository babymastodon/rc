#!/bin/bash

echo "Install kitty:"
echo
echo "  sudo dnf install kitty"
echo "  systemctl --user daemon-reload"
echo "  systemctl --user enable --now kitty-theme-watcher.service"
echo

mkdir -p ~/.config/kitty/
ln -sf $PWD/kitty.conf ~/.config/kitty/kitty.conf

mkdir -p ~/.config/kitty/themes/
ln -sf $PWD/MonokaiPro.conf ~/.config/kitty/themes/MonokaiPro.conf
ln -sf $PWD/MonokaiProLight.conf ~/.config/kitty/themes/MonokaiProLight.conf

mkdir -p ~/bin
ln -sf $PWD/kitty-theme-watcher.sh ~/bin/kitty-theme-watcher.sh

mkdir -p ~/.config/systemd/user
ln -sf $PWD/kitty-theme-watcher.service ~/.config/systemd/user/kitty-theme-watcher.service
