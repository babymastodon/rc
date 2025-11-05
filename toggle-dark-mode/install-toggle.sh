#!/bin/bash

pth=$HOME/.local/bin/
dst=$pth/toggle-dark-mode.sh
mkdir -p $pth
ln -sf $PWD/toggle-dark-mode.sh $dst

echo "Install toggle-dark-mode.sh:"
echo
echo "  installed to: $dst"
echo
