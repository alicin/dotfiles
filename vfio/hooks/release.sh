#!/usr/bin/env bash
# vfio release hook for the `win11` domain. Runs as ROOT after QEMU has fully stopped and
# released its devices. Best-effort reversal of prepare.sh — never abort; log and continue.
# Installed to /etc/libvirt/hooks/vfio/release.sh.
set -uo pipefail

GPU="0000:01:00.0"
AUDIO="0000:01:00.1"
NVME="0000:02:00.0"
MOUNT_STATE="/run/vfio-win11.mounts"   # written by prepare.sh: the host mounts it released

log(){ echo "[vfio-release] $*" | systemd-cat -t vfio-hook -p info; echo "[vfio-release] $*" >&2; }

log "=== releasing win11 passthrough ==="

# 1) Give the host its cores + a sane governor back.
for slice in system.slice user.slice; do
  systemctl set-property --runtime "$slice" AllowedCPUs=0-15 2>/dev/null || true
done
command -v cpupower >/dev/null 2>&1 && cpupower frequency-set -g powersave >/dev/null 2>&1 || true

# 2) (No explicit hugepage pool is used — guest RAM is THP-backed. Nothing to free.)

# 3) NVMe FIRST: rebind the Samsung controller to the host nvme driver and put back whatever
#    prepare.sh unmounted, BEFORE the Integrated switch below (supergfxd rmmods vfio-pci then —
#    NVMe must be off it).
log "rebinding NVMe $NVME -> nvme"
if [ -e "/sys/bus/pci/devices/$NVME/driver" ]; then
  echo "$NVME" > "/sys/bus/pci/devices/$NVME/driver/unbind" 2>/dev/null || true
fi
echo > "/sys/bus/pci/devices/$NVME/driver_override" 2>/dev/null || true
modprobe nvme 2>/dev/null || true
echo "$NVME" > /sys/bus/pci/drivers_probe 2>/dev/null || true

# Wait on the controller's own nvme node, not a fixed /dev name: the disk re-enumerates across a
# detach/reattach and can come back under a different number (see prepare.sh).
for _ in $(seq 1 20); do
  [ -n "$(ls -d /sys/bus/pci/devices/$NVME/nvme/nvme*/nvme*n1 2>/dev/null)" ] && break
  sleep 0.5
done
if [ -z "$(ls -d /sys/bus/pci/devices/$NVME/nvme/nvme*/nvme*n1 2>/dev/null)" ]; then
  log "WARN: no nvme node under $NVME after 10s — host mounts not restored (check \`dmesg\`)"
elif [ -s "$MOUNT_STATE" ]; then
  command -v udevadm >/dev/null 2>&1 && udevadm settle -t 10 >/dev/null 2>&1
  # Anything that fails stays in the state file, so re-running this hook by hand retries it.
  failed=""
  while read -r mp; do
    [ -n "$mp" ] || continue
    if mountpoint -q "$mp"; then
      log "$mp already mounted"
    elif mount "$mp" 2>/dev/null; then
      log "remounted $mp"
    else
      log "WARN: could not remount $mp (no /etc/fstab entry, or the guest left the volume dirty)"
      failed="$failed$mp
"
    fi
  done < "$MOUNT_STATE"
  printf '%s' "$failed" > "$MOUNT_STATE"
  [ -s "$MOUNT_STATE" ] || rm -f "$MOUNT_STATE"
else
  log "no host mounts were released; nothing to restore"
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
