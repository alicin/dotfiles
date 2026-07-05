#!/usr/bin/env bash
# vfio release hook for the `win11` domain. Runs as ROOT after QEMU has fully stopped and
# released its devices. Best-effort reversal of prepare.sh — never abort; log and continue.
# Installed to /etc/libvirt/hooks/vfio/release.sh.
set -uo pipefail

GPU="0000:01:00.0"
AUDIO="0000:01:00.1"
NVME="0000:02:00.0"
FAT_MNT="/mnt/fat"
FAT_UUID="4bce39ac-362e-4703-b81f-f0b9e452cede"   # nvme0n1p5 (ext4). `blkid` if it ever changes.
NVME_PART="/dev/nvme0n1p5"

log(){ echo "[vfio-release] $*" | systemd-cat -t vfio-hook -p info; echo "[vfio-release] $*" >&2; }

log "=== releasing win11 passthrough ==="

# 1) Give the host its cores + a sane governor back.
for slice in system.slice user.slice; do
  systemctl set-property --runtime "$slice" AllowedCPUs=0-15 2>/dev/null || true
done
command -v cpupower >/dev/null 2>&1 && cpupower frequency-set -g powersave >/dev/null 2>&1 || true

# 2) (No explicit hugepage pool is used — guest RAM is THP-backed. Nothing to free.)

# 3) NVMe FIRST: rebind the Samsung controller to the host nvme driver and remount /mnt/fat,
#    BEFORE the Integrated switch below (supergfxd rmmods vfio-pci then — NVMe must be off it).
log "rebinding NVMe $NVME -> nvme"
if [ -e "/sys/bus/pci/devices/$NVME/driver" ]; then
  echo "$NVME" > "/sys/bus/pci/devices/$NVME/driver/unbind" 2>/dev/null || true
fi
echo > "/sys/bus/pci/devices/$NVME/driver_override" 2>/dev/null || true
modprobe nvme 2>/dev/null || true
echo "$NVME" > /sys/bus/pci/drivers_probe 2>/dev/null || true

for _ in $(seq 1 20); do
  [ -b "$NVME_PART" ] && break
  sleep 0.5
done
if [ -b "$NVME_PART" ]; then
  log "remounting $FAT_MNT"
  mount "$FAT_MNT" 2>/dev/null || mount -U "$FAT_UUID" "$FAT_MNT" 2>/dev/null || log "WARN: could not remount $FAT_MNT"
else
  log "WARN: $NVME_PART did not reappear; $FAT_MNT not remounted (check `dmesg`)"
fi

# 4) dGPU LAST: power it back down to 0 W (supergfxd rmmods vfio-pci here). Blackwell reset
#    quirk: if it won't reach D3cold, a host reboot may be needed before the next launch —
#    log it, do NOT loop/retry (can hard-wedge).
log "supergfxctl -m Integrated"
if supergfxctl -m Integrated; then
  sleep 2
  ps=$(cat "/sys/bus/pci/devices/$GPU/power_state" 2>/dev/null || echo "removed")
  log "dGPU power_state: $ps"
  case "$ps" in
    D3cold|removed) : ;;
    *) log "WARN: dGPU not at D3cold ($ps) — reset quirk; a host reboot may be required before relaunch" ;;
  esac
else
  log "WARN: supergfxctl -m Integrated failed — dGPU may be wedged; host reboot may be required"
fi

log "=== release complete ==="
