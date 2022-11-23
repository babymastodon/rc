#!/bin/bash

# link config files
ln -sf $PWD/vimrc ~/.vimrc
ln -sf $PWD/ideavimrc ~/.ideavimrc
ln -sf $PWD/tmux.conf ~/.tmux.conf
ln -sf $PWD/bashrc_extra ~/.bashrc_extra
ln -sf $PWD/gitignore_global ~/.gitignore_global
mkdir -p ~/.vim/syntax/
ln -sf $PWD/coffee.vim ~/.vim/syntax/coffee.vim
mkdir -p ~/.vim/indent/
ln -sf $PWD/coffee.indent.vim ~/.vim/indent/coffee.vim
mkdir -p ~/.vim/colors/
ln -sf $PWD/colors/summerfruit256.vim ~/.vim/colors/summerfruit256.vim


# source .bashrc_extra from .bashrc
touch ~/.bashrc
cat ~/.bashrc | grep -v 'bashrc_extra' > /tmp/bashrc
echo source ~/.bashrc_extra >> /tmp/bashrc
mv /tmp/bashrc ~/.bashrc
source ~/.bashrc


# install scripts into the bin
mkdir -p ~/bin


# install config files into etc
mkdir -p ~/etc


# install vim plugins
if [ ! -d ~/.vim/bundle/vundle ]
then
  mkdir -p ~/.vim/bundle
  git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
fi

# install git completion
if [ ! -f ~/.git-completion.bash ]
then
  curl https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash > ~/.git-completion.bash
fi

# set git defaults
git config --global core.editor vim
git config --global core.excludesfile ~/.gitignore_global
git config --global push.default current
