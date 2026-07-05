#!/usr/bin/env bash
# preflight.sh — Phase 0 de-risk. Proves the three make-or-break unknowns BEFORE building
# the polished VM, on this specific 2026 Blackwell muxless laptop:
#   (1) does kernel 7.x bind the dGPU to vfio-pci under iommu=pt?
#   (2) is the dGPU IOMMU group clean, and what are its PCI IDs?
#   (3) does the dGPU survive repeated Vfio<->Integrated round-trips (reset bug)?
#
# Run from an interactive Hyprland terminal:  sudo ./vfio/scripts/preflight.sh
# Reversible: it always tries to return the dGPU to Integrated (0 W) at the end.
set -uo pipefail
GPU="0000:01:00.0"; AUDIO="0000:01:00.1"
[ "$(id -u)" -eq 0 ] || { echo "run as root (sudo)"; exit 1; }
driver_of(){ [ -L "/sys/bus/pci/devices/$1/driver" ] && basename "$(readlink "/sys/bus/pci/devices/$1/driver")" || echo "(none)"; }
pstate(){ cat "/sys/bus/pci/devices/$1/power_state" 2>/dev/null || echo "removed"; }

echo "### current mode: $(supergfxctl -g 2>/dev/null) / power: $(supergfxctl -S 2>/dev/null)"
echo "### cmdline: $(cat /proc/cmdline)"
echo

echo "=== [1/4] switch to Vfio and time it ==="
t0=$SECONDS
supergfxctl -m Vfio || { echo "FAIL: supergfxctl -m Vfio errored"; exit 1; }
for _ in $(seq 1 120); do   # first cold switch can take >25s
  [ "$(driver_of "$GPU")" = "vfio-pci" ] && [ "$(driver_of "$AUDIO")" = "vfio-pci" ] && break
  sleep 0.5
done
elapsed=$((SECONDS - t0))
echo "forward switch took ~${elapsed}s (size the hook BIND_TIMEOUT above this)"
echo "  $GPU   driver=$(driver_of "$GPU")   power=$(pstate "$GPU")"
echo "  $AUDIO driver=$(driver_of "$AUDIO") power=$(pstate "$AUDIO")"

echo
echo "=== [2/4] iommu=pt gate + PCI IDs + IOMMU group cleanliness ==="
if [ "$(driver_of "$GPU")" != "vfio-pci" ]; then
  echo "!! dGPU did NOT bind to vfio-pci. Checking dmesg for the Blackwell unity-mapping gate:"
  dmesg | grep -iE 'vfio|iommu|identity|unity|0x7f|header type' | tail -20
  echo "   FIX: drop 'iommu=pt' from the systemd-boot entry (keep intel_iommu=on), reboot, retry."
else
  echo "dGPU PCI IDs (record these):"
  lspci -nnk -s 01:00.0; lspci -nnk -s 01:00.1
  grp=$(basename "$(dirname "$(dirname "$(readlink -f /sys/bus/pci/devices/$GPU/iommu_group)")")" 2>/dev/null)
  echo "IOMMU group members (want only 01:00.0 + 01:00.1, maybe the root port):"
  for d in /sys/bus/pci/devices/$GPU/iommu_group/devices/*; do echo "  $(basename "$d"): $(lspci -nns "$(basename "$d")")"; done
fi

echo
echo "=== [3/4] round-trip Vfio<->Integrated x5 (reset-bug check) ==="
fail=0
for i in $(seq 1 5); do
  supergfxctl -m Integrated >/dev/null 2>&1; sleep 2
  ps=$(pstate "$GPU"); echo "  cycle $i: Integrated -> power=$ps"
  [ "$ps" = "D3cold" ] || [ "$ps" = "removed" ] || { echo "    WARN: not at D3cold"; fail=1; }
  supergfxctl -m Vfio >/dev/null 2>&1
  for _ in $(seq 1 40); do [ "$(driver_of "$GPU")" = "vfio-pci" ] && break; sleep 0.5; done
  drv=$(driver_of "$GPU"); echo "  cycle $i: Vfio -> driver=$drv"
  [ "$drv" = "vfio-pci" ] || { echo "    FAIL: did not re-bind on cycle $i (reset bug)"; fail=1; break; }
done

echo
echo "=== [4/4] return to Integrated (0 W) ==="
supergfxctl -m Integrated >/dev/null 2>&1; sleep 2
echo "final: mode=$(supergfxctl -g 2>/dev/null) power=$(supergfxctl -S 2>/dev/null) gpu_power=$(pstate "$GPU")"
echo
if [ "$fail" -eq 0 ]; then
  echo "PASS ✅  — hot-plug + reset look solid. Proceed to Phase 1 (boot Windows)."
else
  echo "ATTENTION ⚠️  — see WARN/FAIL above. Try: hotplug_type=Asus (reboot) and/or"
  echo "   uncomment 'disable_idle_d3=1' in /etc/modprobe.d/vfio-dgpu.conf (mkinitcpio -P; reboot)."
fi
