#!/bin/bash
# install_walls.sh — installs https://github.com/dharmx/walls.git into ~/Pictures/

# Exit immediately if a command exits with a non-zero status
set -e

# Define target directory
TARGET_DIR="$HOME/Pictures/walls"

echo "Installing dharmx/walls into $TARGET_DIR ..."

# Check for git
if ! command -v git &>/dev/null; then
    echo "Error: git is not installed. Please install git first."
    exit 1
fi

# Clone or update repository
if [ -d "$TARGET_DIR/.git" ]; then
    echo "Repository already exists. Pulling latest changes..."
    cd "$TARGET_DIR"
    git pull
else
    echo "Cloning repository..."
    git clone https://github.com/dharmx/walls.git "$TARGET_DIR"
fi

echo "Installation complete!"
echo "Files are located in: $TARGET_DIR"

