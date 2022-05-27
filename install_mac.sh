#!/bin/bash

ln -sf $PWD/bashrc_mac ~/.bashrc_mac

# source .bashrc_mac from .bashrc
touch ~/.bashrc
cat ~/.bashrc | grep -v 'bashrc_mac' > /tmp/bashrc
echo source ~/.bashrc_mac >> /tmp/bashrc
mv /tmp/bashrc ~/.bashrc
source ~/.bashrc
