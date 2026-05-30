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

    # Arch-specific services (Debian auto-enables services via apt)
    if is_arch; then
        sudo systemctl enable --now systemd-timesyncd.service
        sudo systemctl enable --now fstrim.timer
        sudo systemctl enable --now bluetooth 2>/dev/null || true
        sudo systemctl enable --now cronie
        sudo systemctl enable --now avahi-daemon.service
        sudo systemctl enable --now sshd
        sudo systemctl enable --now paccache.timer
        sudo systemctl enable docker.service --now
        sudo systemctl enable supergfxd --now 2>/dev/null || true
        sudo systemctl enable input-remapper.service --now 2>/dev/null || true
        systemctl --user daemon-reload
        systemctl --user enable --now yay-cache-clean.timer
    fi

    # Virtualization services (if available, cross-distro)
    if systemctl list-unit-files | grep -q libvirtd; then
        sudo systemctl enable --now libvirtd
    fi

    echo "Systemd services configured successfully!" 
fi 