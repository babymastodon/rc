#!/bin/bash

# common instructions
bash $PWD/install_basic.sh

ln -sf $PWD/bashrc_linux ~/.bashrc_linux

# source .bashrc_linux from .bashrc
touch ~/.bashrc
cat ~/.bashrc | grep -v 'bashrc_linux' > /tmp/bashrc
echo source ~/.bashrc_linux >> /tmp/bashrc
mv /tmp/bashrc ~/.bashrc
source ~/.bashrc
