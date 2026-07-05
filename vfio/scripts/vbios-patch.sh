#!/usr/bin/env bash
# vbios-patch.sh — strip the header off a raw NVIDIA vBIOS dump so it's usable as a
# passthrough <rom>. Only needed if the guest driver shows Code 43 (muxless dGPU can't
# read its ROM shadow through the vfio BAR). See vbios-dump.md for how to OBTAIN the raw rom.
#
#   ./vfio/scripts/vbios-patch.sh /path/to/raw_nvidia.rom
# Output: /var/lib/libvirt/vbios/nvidia_patched.rom  (then uncomment <rom .../> in win11.xml)
set -euo pipefail
RAW="${1:-}"
OUT="/var/lib/libvirt/vbios/nvidia_patched.rom"
[ -f "$RAW" ] || { echo "usage: $0 <raw_nvidia.rom>"; exit 1; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
PATCHER="$WORK/patcher.py"
if command -v nvidia-vbios-vfio-patcher >/dev/null; then
  sudo mkdir -p "$(dirname "$OUT")"
  sudo nvidia-vbios-vfio-patcher -i "$RAW" -o "$OUT"
else
  echo "Fetch the patcher (needs network):  git clone https://github.com/Matoking/NVIDIA-vBIOS-VFIO-Patcher"
  echo "Then:  python NVIDIA-vBIOS-VFIO-Patcher/nvidia_vbios_vfio_patcher.py -i '$RAW' -o '$OUT'"
  exit 1
fi
echo "Patched vBIOS -> $OUT"
echo "Uncomment the <rom bar='on' file='$OUT'/> line on the GPU <hostdev> in win11.xml, re-define, reboot the VM."
