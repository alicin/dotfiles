#!/bin/bash

# Dotfiles installer wrapper
# This script prepares the environment and runs the main installation script

set -e  # Exit on error

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source OS detection
source "${SCRIPT_DIR}/lib/os-detection.sh"

echo "==================================="
echo "Dotfiles Installer"
echo "==================================="

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo "Error: Please run this script as a regular user (with sudo access), not as root"
    exit 1
fi

# Check if start.sh exists
if [ ! -f "$SCRIPT_DIR/start.sh" ]; then
    echo "Error: start.sh not found in $SCRIPT_DIR"
    exit 1
fi

# Handle Arch Linux - install prerequisites
if is_arch; then
    echo ""
    echo "Detected Arch Linux - Installing essential packages..."
    sudo pacman -Syu --needed --noconfirm git jq fakeroot debugedit zsh
    
    echo ""
    echo "Switching to zsh and running start.sh..."
    exec zsh -c "cd '$SCRIPT_DIR' && ./start.sh $*"
fi

# Handle other Linux distributions - switch to zsh
if is_linux && ! is_arch; then
    echo ""
    echo "Detected Linux - Switching to zsh and running start.sh..."
    exec zsh -c "cd '$SCRIPT_DIR' && ./start.sh $*"
fi

# Handle macOS - zsh is default, just run start.sh
if is_macos; then
    echo ""
    echo "Detected macOS - Running start.sh..."
    exec "$SCRIPT_DIR/start.sh" "$@"
fi
