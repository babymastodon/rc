#!/bin/bash

# install node for pyright language server
curl -sL https://deb.nodesource.com/setup_16.x -o /tmp/nodesource_setup.sh
sudo bash /tmp/nodesource_setup.sh
sudo apt install nodejs

# install plugins
vim +PluginInstall +qall

# install youcompleteme
sudo apt install build-essential cmake vim-nox python3-dev
sudo apt install mono-complete golang openjdk-17-jdk openjdk-17-jre
cd ~/.vim/bundle/YouCompleteMe
python3 install.py --all
