#!/bin/bash

# link config files
ln -sf $PWD/vimrc ~/.vimrc
ln -sf $PWD/tmux.conf ~/.tmux.conf
ln -sf $PWD/bashrc_extra ~/.bashrc_extra


# source .bashrc_extra from .bashrc
touch ~/.bashrc
cat ~/.bashrc | grep -v 'source .bashrc_extra' > /tmp/bashrc
echo source .bashrc_extra >> /tmp/bashrc
mv /tmp/bashrc ~/.bashrc


# install scripts into the bin
mkdir -p ~/bin
ln -sf $PWD/trackpoint.sh ~/bin/


# enable italic fonts in the terminal
bash ./enable_italics.sh
