#!/usr/bin/env bash
# game.sh — one-shot launcher for the win11 passthrough VM. Run as your normal user.
#
#   1. `virsh start win11`  → libvirt's qemu hook powers up the dGPU, releases /mnt/fat,
#                             and isolates the P-cores (guest RAM is THP-backed, no hugepage pool)
#   2. launches the Looking Glass client (Ctrl+Ctrl toggles input grab host<->guest)
#   3. on client exit: shuts the VM down (hook powers the dGPU back to 0 W, restores
#                      /mnt/fat + CPUs)
#
# Keep a second (USB) keyboard or an SSH session handy the first few times, in case the
# Ctrl+Ctrl grab toggle misbehaves.
set -uo pipefail

VM="win11"
VIRSH="virsh -c qemu:///system"
LG_INI="${LG_INI:-$HOME/.config/looking-glass/client.ini}"

cleanup(){
  echo "[game] shutting down $VM ..."
  $VIRSH shutdown "$VM" 2>/dev/null || true
  for _ in $(seq 1 90); do
    [ "$($VIRSH domstate "$VM" 2>/dev/null)" = "shut off" ] && break
    sleep 2
  done
  if [ "$($VIRSH domstate "$VM" 2>/dev/null)" != "shut off" ]; then
    echo "[game] guest didn't shut down in time — forcing off"
    $VIRSH destroy "$VM" 2>/dev/null || true
  fi
  echo "[game] done. dGPU: $(supergfxctl -S 2>/dev/null || echo '?')"
}
trap cleanup EXIT INT TERM

command -v looking-glass-client >/dev/null 2>&1 || { echo "looking-glass-client not installed → yay -S looking-glass"; exit 1; }
$VIRSH dominfo "$VM" >/dev/null 2>&1 || { echo "domain $VM not defined → virsh define vfio/win11.xml"; exit 1; }
if [ "$($VIRSH domstate "$VM" 2>/dev/null)" = "running" ]; then
  echo "[game] $VM already running — attaching client only"
else
  echo "[game] starting $VM (hook powers up the dGPU + releases /mnt/fat) ..."
  $VIRSH start "$VM"
fi

echo "[game] launching Looking Glass — Ctrl+Ctrl toggles input grab"
looking-glass-client -C "$LG_INI" || true
# client exit → trap cleanup() shuts the VM down
