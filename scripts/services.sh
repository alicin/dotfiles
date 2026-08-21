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

        # Everything else this repo ships a user unit for. Enablement lives here
        # rather than in committed *.target.wants/ symlinks for the reason above:
        # on h4l9000 that directory IS the repo, so `systemctl --user enable`
        # wrote into the working tree, and whatever one machine happened to
        # enable arrived in every other checkout. The symlinks are gitignored now
        # and this list is the source of truth.
        #
        # Each is guarded on the unit actually existing, because the set differs
        # per machine and per install order: the toshy-* units arrive with
        # toshy-install.sh (which runs before this script), appimagelauncherd
        # comes from a package, and a host without either should skip them
        # quietly rather than fail.
        #
        # Deliberately NOT here: h4l9000-sys.service (laptop telemetry for one
        # dashboard) and Sunshine. Those are one machine's business; they stay
        # enabled on that machine and out of everyone else's session.
        for unit in \
            toshy-config.service \
            toshy-session-monitor.service \
            toshy-cosmic-dbus.service \
            toshy-kwin-dbus.service \
            toshy-wlroots-dbus.service \
            rclone-gdrive.service \
            appimagelauncherd.service
        do
            if systemctl --user cat "$unit" >/dev/null 2>&1; then
                systemctl --user enable "$unit" >/dev/null 2>&1 \
                    && echo "  enabled $unit" \
                    || echo "  WARN: could not enable $unit"
            fi
        done
    fi

    # Virtualization services (if available, cross-distro)
    if systemctl list-unit-files | grep -q libvirtd; then
        sudo systemctl enable --now libvirtd
    fi

    echo "Systemd services configured successfully!" 
fi 