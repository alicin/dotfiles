#!/usr/bin/env bash
# vfio prepare hook for the `win11` domain. Runs as ROOT, before QEMU opens any device.
# FATAL errors exit nonzero so libvirt aborts the start cleanly (better than QEMU opening
# a half-bound device). Installed to /etc/libvirt/hooks/vfio/prepare.sh.
set -uo pipefail

GPU="0000:01:00.0"        # NVIDIA dGPU (Blackwell)
AUDIO="0000:01:00.1"      # dGPU HDMI/DP audio function
NVME="0000:02:00.0"       # Samsung 970 EVO Plus controller (whole-disk passthrough)
FAT_MNT="/mnt/fat"        # ext4 partition (nvme0n1p5) living on the SAME disk we pass through
HOST_CPUS="6-15"          # confine the host here while the VM owns P-cores 0-5
BIND_TIMEOUT=60           # seconds to wait for the dGPU on vfio-pci (first cold switch can take >25s)

log(){ echo "[vfio-prepare] $*" | systemd-cat -t vfio-hook -p info; echo "[vfio-prepare] $*" >&2; }
die(){ echo "[vfio-prepare] FATAL: $*" | systemd-cat -t vfio-hook -p err; echo "[vfio-prepare] FATAL: $*" >&2; exit 1; }
driver_of(){ [ -L "/sys/bus/pci/devices/$1/driver" ] && basename "$(readlink "/sys/bus/pci/devices/$1/driver")" || echo "(none)"; }

bind_vfio(){  # $1 = pci addr
  local d="$1"
  if [ -e "/sys/bus/pci/devices/$d/driver" ]; then
    echo "$d" > "/sys/bus/pci/devices/$d/driver/unbind" 2>/dev/null || true
  fi
  echo vfio-pci > "/sys/bus/pci/devices/$d/driver_override"
  echo "$d" > /sys/bus/pci/drivers_probe
}

log "=== preparing win11 passthrough ==="

# 1) dGPU FIRST. supergfxd owns the vfio-pci module lifecycle (it modprobe/rmmods it per mode
#    switch). Binding any OTHER device to vfio-pci before this stalls supergfxd's PCI rescan,
#    so the GPU must go through supergfxd before we touch the NVMe.
log "supergfxctl -m Vfio"
supergfxctl -m Vfio || die "supergfxctl -m Vfio failed"

# supergfxd's -m Vfio relies on the `ids=` in its modprobe.d taking effect when it (re)inserts
# vfio-pci. That only happens if the module is actually inserted at switch time — if vfio_pci is
# pinned in the initramfs and already resident, the modprobe is a no-op and NOTHING binds, so the
# wait below would time out (see mkinitcpio MODULES: keep vfio_pci OUT so this insert is real).
# Don't trust the ids path regardless: wait for the dGPU to reappear on the bus after the rescan,
# then bind GPU+AUDIO explicitly via driver_override (same mechanism as the NVMe below).
deadline=$((SECONDS + BIND_TIMEOUT))
while [ ! -e "/sys/bus/pci/devices/$GPU" ] || [ ! -e "/sys/bus/pci/devices/$AUDIO" ]; do
  [ "$SECONDS" -lt "$deadline" ] || die "timeout waiting for dGPU to reappear on the PCI bus (supergfxctl -m Vfio / rescan / hotplug_type)"
  sleep 0.5
done
modprobe vfio-pci 2>/dev/null || true
for d in "$GPU" "$AUDIO"; do
  [ "$(driver_of "$d")" = "vfio-pci" ] || bind_vfio "$d"
done
while :; do
  if [ "$(driver_of "$GPU")" = "vfio-pci" ] && [ "$(driver_of "$AUDIO")" = "vfio-pci" ]; then
    log "dGPU $GPU + $AUDIO bound to vfio-pci"
    break
  fi
  [ "$SECONDS" -lt "$deadline" ] || die "timeout waiting for dGPU on vfio-pci (check iommu=pt gate / supergfxd / driver_override)"
  sleep 0.5
done

# 2) NVMe SECOND. Release the Samsung NVMe from the host (it carries /mnt/fat AND the Windows
#    install) and bind it to the now-loaded vfio-pci. Refuse to continue if /mnt/fat can't be
#    freed (two kernels writing one disk = corruption).
if mountpoint -q "$FAT_MNT"; then
  log "unmounting $FAT_MNT"
  sync
  umount "$FAT_MNT" || die "could not unmount $FAT_MNT (in use). Close anything using it, then retry."
fi
log "binding NVMe $NVME -> vfio-pci"
modprobe vfio-pci 2>/dev/null || true
bind_vfio "$NVME"
[ "$(driver_of "$NVME")" = "vfio-pci" ] || die "NVMe $NVME did not bind to vfio-pci"

# 4) Memory: THP (=always) backs the guest RAM with 2M pages; no explicit hugepage pool (20GiB
#    isn't reliably allocatable as 2M at runtime). Just compact to help THP form big pages.
echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true

# 5) Confine host tasks to E/LP-E cores so the 6 P-cores are jitter-free for the guest.
#    Per-slice (init.scope rejects AllowedCPUs); non-fatal.
log "confining host to CPUs $HOST_CPUS"
for slice in system.slice user.slice; do
  systemctl set-property --runtime "$slice" "AllowedCPUs=$HOST_CPUS" 2>/dev/null || log "WARN: AllowedCPUs on $slice failed"
done

# 6) Performance governor for the run.
command -v cpupower >/dev/null 2>&1 && cpupower frequency-set -g performance >/dev/null 2>&1 || true

log "=== prepare complete ==="
