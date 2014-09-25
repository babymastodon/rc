#!/bin/bash

# common instructions
bash $PWD/install_basic.sh


# install scripts into the bin
ln -sf $PWD/trackpoint.sh ~/bin/


# enable italic fonts in the terminal
bash ./enable_italics.sh


# set git defaults
git config --global user.email "hogbait@gmail.com"
git config --global user.name "Zack Drach"
