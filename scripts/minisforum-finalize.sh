#!/usr/bin/env bash

# Minisforum V3 finalisation: ALSA soft-mixer + audio module options.
#
# Previously this copied into /etc without sudo (and without creating
# /etc/wireplumber/wireplumber.conf.d first), so the system-wide half failed
# every time it ran as a normal user -- which is how profile-install.sh invokes
# post_install scripts. Only the ~/.config copy ever landed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/../system/etc"

MIXER_CONF="${SRC_DIR}/alsa-soft-mixer.conf"
AUDIO_CONF="${SRC_DIR}/audio.conf"

for f in "${MIXER_CONF}" "${AUDIO_CONF}"; do
    if [[ ! -f "$f" ]]; then
        echo "ERROR: missing source file: $f" >&2
        exit 1
    fi
done

# ── ALSA soft mixer: system-wide and per-user ───────────────────────────────
echo "Installing alsa-soft-mixer.conf (system)"
sudo mkdir -p /etc/wireplumber/wireplumber.conf.d
sudo install -m 0644 "${MIXER_CONF}" /etc/wireplumber/wireplumber.conf.d/alsa-soft-mixer.conf

echo "Installing alsa-soft-mixer.conf (user)"
mkdir -p "${HOME}/.config/wireplumber/wireplumber.conf.d"
install -m 0644 "${MIXER_CONF}" "${HOME}/.config/wireplumber/wireplumber.conf.d/alsa-soft-mixer.conf"

# ── Audio module options ────────────────────────────────────────────────────
echo "Installing audio.conf to /etc/modprobe.d"
sudo install -m 0644 "${AUDIO_CONF}" /etc/modprobe.d/audio.conf

echo "Minisforum audio configuration applied."
echo "Restart audio with: systemctl --user restart wireplumber.service pipewire.service"
