#!/bin/bash

# common instructions
bash $PWD/install_basic.sh


ln -sf $PWD Xmodmap ~/.xmodmaprc
ln -sf $PWD Xmodmap ~/.Xmodmap


# set git defaults
git config --global user.email "hogbait@gmail.com"
git config --global user.name "Zack Drach"
