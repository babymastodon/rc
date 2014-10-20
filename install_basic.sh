#!/bin/bash

# link config files
ln -sf $PWD/vimrc ~/.vimrc
ln -sf $PWD/tmux.conf ~/.tmux.conf
ln -sf $PWD/bashrc_extra ~/.bashrc_extra
ln -sf $PWD/gitignore_global ~/.gitignore_global


# source .bashrc_extra from .bashrc
touch ~/.bashrc
cat ~/.bashrc | grep -v 'bashrc_extra' > /tmp/bashrc
echo source ~/.bashrc_extra >> /tmp/bashrc
mv /tmp/bashrc ~/.bashrc
source ~/.bashrc


# install scripts into the bin
mkdir -p ~/bin


# install vim plugins
if [ ! -d ~/.vim/bundle/vundle ]
then
  mkdir -p ~/.vim/bundle
  git clone https://github.com/gmarik/vundle.git ~/.vim/bundle/vundle
fi

# set git defaults
git config --global core.editor vim
git config --global push.default simple
git config --global core.excludesfile ~/.gitignore_global
