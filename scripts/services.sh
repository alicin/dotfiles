#!/bin/bash

# Source OS detection utilities
source "$(dirname "$0")/../lib/os-detection.sh"

if is_macos; then
    echo "Setting up brew services for macOS..."
    brew services start redis
    yabai --start-service
    skhd --start-service
    brew services start sketchybar
    brew services start felixkratz/formulae/borders
fi

if is_linux; then
    echo "Setting up systemd services..."

    if is_arch; then

        # Enable essential services
        sudo systemctl enable --now cronie
        sudo systemctl enable --now systemd-timesyncd.service
        sudo systemctl enable --now avahi-daemon.service
        sudo systemctl enable --now sshd
        sudo systemctl enable --now paccache.timer
        sudo systemctl enable --now fstrim.timer
        sudo systemctl enable --now bluetooth

        # Virtualization services (if available)
        if systemctl list-unit-files | grep -q libvirtd; then
        sudo systemctl enable --now libvirtd
            sudo usermod -aG libvirt,kvm $(whoami)
        fi
    
    fi

    systemctl --user enable --now hyprpolkitagent.service

    echo "Systemd services configured successfully!" 
fi 