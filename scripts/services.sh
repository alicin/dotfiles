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

        # The Quickshell shell. config/hypr/lua/apps.lua starts the bar with
        # `systemctl --user is-enabled --quiet qshell.service && systemctl
        # --user restart qshell.service || <fallback>` -- so if the unit is
        # never enabled the session silently drops to the unsupervised
        # fallback path and a crashed shell stays dead. Enable, don't --now:
        # it is WantedBy=graphical-session.target and Hyprland starts it.
        #
        # The unit is copied rather than reached through a linked
        # ~/.config/systemd. Only h4l9000 symlinks that whole directory into the
        # repo, and doing it elsewhere has two problems: its committed
        # *.target.wants/ entries would enable h4l9000-sys.service, Sunshine and
        # appimagelauncherd on a machine that has none of them; and because the
        # directory IS the repo, every `systemctl --user enable` writes a new
        # symlink into the tracked tree.
        qshell_src="$(dirname "$0")/../config/systemd/user/qshell.service"
        qshell_dst="${HOME}/.config/systemd/user/qshell.service"
        if [[ ! -e "$qshell_dst" && -f "$qshell_src" ]]; then
            mkdir -p "${HOME}/.config/systemd/user"
            install -m 0644 "$qshell_src" "$qshell_dst"
            systemctl --user daemon-reload
        fi
        if [[ -e "$qshell_dst" ]]; then
            systemctl --user enable qshell.service
        fi
    fi

    # Virtualization services (if available, cross-distro)
    if systemctl list-unit-files | grep -q libvirtd; then
        sudo systemctl enable --now libvirtd
    fi

    echo "Systemd services configured successfully!" 
fi 