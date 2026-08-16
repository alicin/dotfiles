#!/usr/bin/env bash
# game.sh — one-shot launcher for the win11 passthrough VM. Run as your normal user.
#
#   1. `virsh start win11`  → libvirt's qemu hook powers up the dGPU, releases /mnt/fat,
#                             and isolates the P-cores (guest RAM is THP-backed, no hugepage pool)
#   2. waits for the guest's Looking Glass host app to publish an LGMP session in the shm
#   3. launches the Looking Glass client (Ctrl+Ctrl toggles input grab host<->guest)
#   4. on client exit: shuts the VM down (hook powers the dGPU back to 0 W, restores
#                      /mnt/fat + CPUs)
#
# Why step 2 exists: the old version launched the client immediately after `virsh start`, and
# `cleanup` fired on ANY client exit. A client that quit because the guest was still booting would
# therefore shut the VM down ~30 s in — which reads exactly like the guest crashing, and cost a
# long debugging detour on 2026-08-16. The client is now only started once the guest is actually
# publishing frames, and a VM that never got that far is LEFT RUNNING so it can be inspected.
#
# Keep a second (USB) keyboard or an SSH session handy the first few times, in case the
# Ctrl+Ctrl grab toggle misbehaves.
set -uo pipefail

VM="win11"
VIRSH="virsh -c qemu:///system"
LG_INI="${LG_INI:-$HOME/.config/looking-glass/client.ini}"
SHM="${LG_SHM:-/dev/shm/looking-glass}"
LG_WAIT="${LG_WAIT:-180}"    # seconds to wait for the guest host app before giving up
LG_STRICT="${LG_STRICT:-0}"  # 1 = always shut the VM down on exit, even if LG never attached

started_vm=0
attached=0
user_abort=0

# The LGMP header magic is the first 4 bytes of the shared buffer. It PERSISTS across runs, so it
# must be zeroed before boot — otherwise last session's magic reads as "guest is ready" instantly.
shm_magic(){ head -c 4 "$SHM" 2>/dev/null; }
shm_clear(){
  [ -w "$SHM" ] || return 0
  dd if=/dev/zero of="$SHM" bs=16 count=1 conv=notrunc status=none 2>/dev/null || true
}

cleanup(){
  if [ "$started_vm" -eq 1 ] && [ "$attached" -eq 0 ] && [ "$user_abort" -eq 0 ] && [ "$LG_STRICT" != "1" ]; then
    echo
    echo "[game] Looking Glass never attached — LEAVING $VM running so you can inspect it."
    echo "[game]   the dGPU's HDMI head is live, so a connected monitor shows the guest directly"
    echo "[game]   retry client : looking-glass-client -C $LG_INI"
    echo "[game]   guest log    : C:\\ProgramData\\Looking Glass (host)\\looking-glass-host.txt"
    echo "[game]   shut down    : $VIRSH shutdown $VM"
    echo "[game]   (set LG_STRICT=1 to always shut down instead)"
    return
  fi
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
on_signal(){ user_abort=1; exit 130; }
trap on_signal INT TERM
trap cleanup EXIT

command -v looking-glass-client >/dev/null 2>&1 || { echo "looking-glass-client not installed → yay -S looking-glass"; exit 1; }
$VIRSH dominfo "$VM" >/dev/null 2>&1 || { echo "domain $VM not defined → virsh define vfio/win11.xml"; exit 1; }

# The guest owns the whole NVMe controller at 02:00.0. A host-side mount of any partition on it
# while the guest is writing is the one way to actually corrupt Windows, so refuse to start.
for part in $(lsblk -ln -o NAME /dev/nvme0n1 2>/dev/null | tail -n +2); do
  if findmnt -S "/dev/$part" >/dev/null 2>&1; then
    echo "[game] REFUSING TO START: /dev/$part is mounted on the host."
    echo "[game] That disk is passed through to the guest — unmount it first:  sudo umount /dev/$part"
    exit 1
  fi
done

if [ "$($VIRSH domstate "$VM" 2>/dev/null)" = "running" ]; then
  echo "[game] $VM already running — attaching client only"
  attached=1
else
  echo "[game] clearing stale LGMP session in $SHM"
  shm_clear
  echo "[game] starting $VM (hook powers up the dGPU + releases /mnt/fat) ..."
  $VIRSH start "$VM" || exit 1
  started_vm=1

  echo -n "[game] waiting up to ${LG_WAIT}s for the guest Looking Glass host app "
  for _ in $(seq 1 "$LG_WAIT"); do
    if [ "$(shm_magic)" = "LGMP" ]; then attached=1; break; fi
    if [ "$($VIRSH domstate "$VM" 2>/dev/null)" = "shut off" ]; then
      echo; echo "[game] the guest powered off on its own while booting — check:"
      echo "[game]   sudo tail -40 /var/log/libvirt/qemu/win11.log"
      exit 1
    fi
    echo -n "."; sleep 1
  done
  echo

  if [ "$attached" -eq 0 ]; then
    echo "[game] no LGMP session after ${LG_WAIT}s — the guest host app never started."
    exit 1
  fi
  echo "[game] guest session is live"
fi

echo "[game] launching Looking Glass — Ctrl+Ctrl toggles input grab"
looking-glass-client -C "$LG_INI" || true
# client exit → trap cleanup() shuts the VM down
