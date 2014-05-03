#!/bin/bash

gsettings set com.canonical.desktop.interface scrollbar-mode normal
mkdir -p ~/.themes
mkdir -p ~/.local/share/themes
ln -sf $PWD/MyAdwaita ~/.themes
ln -sf $PWD/MyAdwaita ~/.local/share/themes


gsettings set org.gnome.desktop.interface cursor-size 24
gsettings set org.gnome.desktop.interface cursor-theme DMZ-White
gsettings set org.gnome.desktop.interface icon-theme ubuntu-mono-dark
gsettings set org.gnome.desktop.interface gtk-theme MyAdwaita
gsettings set org.gnome.desktop.interface clock-format 12h
gsettings set org.gnome.desktop.interface clock-show-date true
gsettings set org.gnome.desktop.interface clock-show-seconds false
gsettings set org.gnome.desktop.wm.preferences theme MyAdwaita
gsettings set org.gnome.desktop.wm.preferences button-layout menu:minimize,maximize,close
