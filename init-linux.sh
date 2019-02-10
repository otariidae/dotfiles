#!/bin/bash

git clone https://github.com/otariidae/dotfiles.git
ln -s dotfiles/.vimrc ~/.vimrc
git clone https://github.com/k-takata/minpac.git \
    ~/.vim/pack/minpac/opt/minpac
