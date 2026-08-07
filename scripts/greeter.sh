#!/usr/bin/env bash

# Install the greetd/tuigreet greeter and make it the display manager.
#
# Arch's archinstall GNOME profile leaves GDM enabled. Two display managers both
# claiming display-manager.service is a boot-time coin flip, so this disables
# whatever is currently enabled before enabling greetd.
#
# GNOME itself is deliberately left installed -- config/hypr/lua/startup.lua runs
# sync-gnome-tweaks-to-gtk, which reads the values GNOME Tweaks writes to dconf.
# Only the *greeter* changes; the GNOME session stays selectable in tuigreet.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${DOTFILES_DIR}/lib/logging.sh"
source "${DOTFILES_DIR}/lib/os-detection.sh"

if ! is_linux; then
    log_substep "Not Linux, skipping greeter setup"
    exit 0
fi

SRC="${DOTFILES_DIR}/system/etc/greetd-config.toml"
DST="/etc/greetd/config.toml"

log_header "Configuring greeter (greetd + tuigreet)"

if ! command -v greetd >/dev/null 2>&1 && ! [[ -f /usr/lib/systemd/system/greetd.service ]]; then
    log_warning "greetd is not installed, skipping"
    exit 0
fi

if ! command -v tuigreet >/dev/null 2>&1; then
    log_warning "tuigreet is not installed -- greetd would fall back to agreety"
fi

# ── Install the config ──────────────────────────────────────────────────────
log_step "Installing ${DST}"
sudo mkdir -p /etc/greetd
if [[ -f "${DST}" ]] && ! sudo cmp -s "${SRC}" "${DST}"; then
    backup="${DST}.bak-$(date +%Y%m%d-%H%M%S)"
    sudo cp -a "${DST}" "${backup}"
    log_substep "Backed up existing config to $(basename "${backup}")"
fi
sudo install -m 0644 -o root -g root "${SRC}" "${DST}"

# ── Hand over from whatever DM is enabled ───────────────────────────────────
current_dm="$(basename "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)" .service)"

if [[ -n "${current_dm}" && "${current_dm}" != "greetd" && "${current_dm}" != "." ]]; then
    log_step "Disabling current display manager: ${current_dm}"
    sudo systemctl disable "${current_dm}.service"
else
    log_substep "No other display manager to disable (current: ${current_dm:-none})"
fi

log_step "Enabling greetd"
sudo systemctl enable greetd.service

log_success "Greeter configured. greetd takes over on the next reboot."
log_info "Verify before rebooting:  systemctl status greetd.service"
log_info "To go back to GDM:        sudo systemctl disable greetd && sudo systemctl enable gdm"
