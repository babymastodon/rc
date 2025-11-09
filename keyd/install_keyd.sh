#!/bin/bash

echo "Install keyd:"
echo

sudo mkdir -p /etc/keyd/
sudo ln -sf $PWD/default.conf /etc/keyd/default.conf

if ! command -v keyd >/dev/null 2>&1; then
  echo "keyd not found — preparing installation..."

  # Check for make
  if ! command -v make >/dev/null 2>&1; then
    echo "Error: 'make' not found. Please install build tools:"
    echo "  sudo dnf install @development-tools"
    exit 1
  fi

  # Clone keyd only if not already cloned
  if [ ! -d "$HOME/code/keyd" ]; then
    mkdir -p ~/code
    pushd ~/code >/dev/null
    git clone https://github.com/rvaiya/keyd
    popd >/dev/null
  fi

  # Build and install
  pushd ~/code/keyd >/dev/null
  make && sudo make install
  sudo systemctl enable --now keyd
  popd >/dev/null

  echo "keyd installed and service started."
else
  echo "keyd already installed — skipping setup."
fi

