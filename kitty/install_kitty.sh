#!/bin/bash

echo "Install kitty:"
echo
echo "  sudo dnf install kitty"
echo

mkdir -p ~/.config/kitty/
ln -sf $PWD/kitty.conf ~/.config/kitty/kitty.conf

mkdir -p ~/.config/kitty/themes/
ln -sf $PWD/MonokaiPro.conf ~/.config/kitty/themes/MonokaiPro.conf
ln -sf $PWD/MonokaiProLight.conf ~/.config/kitty/themes/MonokaiProLight.conf
