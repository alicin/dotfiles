#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# alsa soft mixer
mkdir -p ~/.config/wireplumber/wireplumber.conf.d/
cp "${SCRIPT_DIR}/../system/etc/alsa-soft-mixer.conf" /etc/wireplumber/wireplumber.conf.d/alsa-soft-mixer.conf
cp "${SCRIPT_DIR}/../system/etc/alsa-soft-mixer.conf" ~/.config/wireplumber/wireplumber.conf.d/alsa-soft-mixer.conf

# audio
sudo cp "${SCRIPT_DIR}/../system/etc/audio.conf" /etc/modprobe.d/audio.conf
