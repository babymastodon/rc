#!/bin/bash

# link config files
ln -sf $PWD/vimrc ~/.vimrc
ln -sf $PWD/ideavimrc ~/.ideavimrc
ln -sf $PWD/tmux.conf ~/.tmux.conf
ln -sf $PWD/bashrc_extra ~/.bashrc_extra
ln -sf $PWD/gitignore_global ~/.gitignore_global
mkdir -p ~/.config/btop
cp $PWD/btop.conf ~/.config/btop/btop.conf
mkdir -p ~/.config/ghostty
ln -sf $PWD/ghostty.config ~/.config/ghostty/config


# source .bashrc_extra from .bashrc
touch ~/.bashrc
cat ~/.bashrc | grep -v 'bashrc_extra' > /tmp/bashrc
echo source ~/.bashrc_extra >> /tmp/bashrc
mv /tmp/bashrc ~/.bashrc
source ~/.bashrc

# source .bashrc from .bash_profile
touch ~/.bash_profile
cat ~/.bash_profile | grep -v '.bashrc' > /tmp/bash_profile
echo source ~/.bashrc >> /tmp/bash_profile
mv /tmp/bash_profile ~/.bash_profile

# install scripts into the bin
mkdir -p ~/bin
ln -sf $PWD/git-commit-all ~/bin/git-commit-all
ln -sf $PWD/tmux-git-badge ~/bin/tmux-git-badge
ln -sf $PWD/tmux-ssh-host ~/bin/tmux-ssh-host


# install config files into etc
mkdir -p ~/etc


# install vim plugins
# install vim-plug
if [ ! -f ~/.vim/autoload/plug.vim ]; then
  mkdir -p ~/.vim/autoload
  curl -fLo ~/.vim/autoload/plug.vim \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
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
