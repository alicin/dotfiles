#!/usr/bin/env bash
set -euo pipefail

GPU=0000:01:00.0
AUDIO=0000:01:00.1

echo '=== detach from vfio-pci ==='
[ -e /sys/bus/pci/devices/$GPU/driver/unbind ]   && echo $GPU   | sudo tee /sys/bus/pci/devices/$GPU/driver/unbind
[ -e /sys/bus/pci/devices/$AUDIO/driver/unbind ] && echo $AUDIO | sudo tee /sys/bus/pci/devices/$AUDIO/driver/unbind

echo '=== clear override ==='
echo '' | sudo tee /sys/bus/pci/devices/$GPU/driver_override
echo '' | sudo tee /sys/bus/pci/devices/$AUDIO/driver_override

echo '=== reload host drivers ==='
sudo modprobe snd_hda_intel
sudo modprobe nvidia nvidia_uvm nvidia_modeset nvidia_drm

echo '=== rebind to host ==='
echo $GPU   | sudo tee /sys/bus/pci/drivers_probe
echo $AUDIO | sudo tee /sys/bus/pci/drivers_probe

echo '=== result ==='
lspci -nnk -s 01:00.0
lspci -nnk -s 01:00.1
nvidia-smi || true