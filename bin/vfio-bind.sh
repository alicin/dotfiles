#!/usr/bin/env bash
set -euo pipefail

GPU=0000:01:00.0
AUDIO=0000:01:00.1

echo '=== precheck ==='
lspci -nnk -s 01:00.0
lspci -nnk -s 01:00.1
nvidia-smi || true

echo '=== unload nvidia userspace/kernel stack ==='
sudo modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia || true

echo '=== unbind from current drivers ==='
[ -e /sys/bus/pci/devices/$GPU/driver/unbind ]   && echo $GPU   | sudo tee /sys/bus/pci/devices/$GPU/driver/unbind
[ -e /sys/bus/pci/devices/$AUDIO/driver/unbind ] && echo $AUDIO | sudo tee /sys/bus/pci/devices/$AUDIO/driver/unbind

echo '=== bind to vfio-pci ==='
sudo modprobe vfio-pci
echo vfio-pci | sudo tee /sys/bus/pci/devices/$GPU/driver_override
echo vfio-pci | sudo tee /sys/bus/pci/devices/$AUDIO/driver_override
echo $GPU   | sudo tee /sys/bus/pci/drivers_probe
echo $AUDIO | sudo tee /sys/bus/pci/drivers_probe

echo '=== result ==='
lspci -nnk -s 01:00.0
lspci -nnk -s 01:00.1