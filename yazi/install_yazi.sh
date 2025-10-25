#!/bin/bash

echo "Install yazi:"
echo
echo "  cargo install yazi-build"
echo

mkdir -p ~/.config/yazi/
ln -sf $PWD/yazi.toml ~/.config/yazi/yazi.toml
