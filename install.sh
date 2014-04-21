#!/bin/bash

ln -sf $PWD/vimrc ~/.vimrc
ln -sf $PWD/tmux.conf ~/.tmux.conf
ln -sf $PWD/bashr_extra ~/.bashrc_extra


# source .bashrc_extra from .bashrc
touch ~/.bashrc
cat ~/.bashrc | sed \
    -e 's/source .bashrc_extra//' \
    -e '$s/$/source .bashrc_extra/' > /tmp/bashrc
mv /tmp/bashrc ~/.bashrc


# install scripts into the bin
mkdir -p ~/bin
ln -sf $PWD/trackpoint.sh ~/bin/

# enable italic fonts in the terminal
bash ./enable_italics.sh
