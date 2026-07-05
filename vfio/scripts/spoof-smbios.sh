#!/usr/bin/env bash
# spoof-smbios.sh — write THIS laptop's REAL SMBIOS serials/uuid into the DEFINED libvirt
# domain (win11), for maximum anti-cheat fidelity. Operates on libvirt's private copy only,
# so the real hardware IDs never land in the git repo. Run AFTER `virsh define`.
#
#   sudo ./vfio/scripts/spoof-smbios.sh
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run as root (sudo)"; exit 1; }
VM=win11
command -v dmidecode >/dev/null || { echo "install dmidecode"; exit 1; }
virsh dominfo "$VM" >/dev/null 2>&1 || { echo "define the domain first: virsh define vfio/win11.xml"; exit 1; }

SYS_SERIAL=$(dmidecode -s system-serial-number)
SYS_UUID=$(dmidecode -s system-uuid)
SYS_SKU=$(dmidecode -s system-product-name)
BRD_SERIAL=$(dmidecode -s baseboard-serial-number)
CHS_SERIAL=$(dmidecode -s chassis-serial-number)

TMP=$(mktemp --suffix=.xml)
virsh dumpxml "$VM" > "$TMP"
sedq(){ printf '%s' "$1" | sed 's/[&/|]/\\&/g'; }
# Replace the distinct generic tokens with real values (quote-agnostic value match).
sed -i \
  -e "s|M0N0CV00SYS000|$(sedq "$SYS_SERIAL")|g" \
  -e "s|M0N0CV00BRD000|$(sedq "${BRD_SERIAL:-$SYS_SERIAL}")|g" \
  -e "s|M0N0CV00CHS000|$(sedq "${CHS_SERIAL:-$SYS_SERIAL}")|g" \
  -e "s|9f8e7d6c-5b4a-4321-9edc-ba9876543210|$(sedq "$SYS_UUID")|g" \
  "$TMP"

# The uuid appears in BOTH <uuid> and <sysinfo> (libvirt requires them equal) and we're changing
# it, so undefine first (keep the SB-enrolled nvram) then redefine.
virsh undefine "$VM" --keep-nvram >/dev/null 2>&1 || true
virsh define "$TMP" >/dev/null && echo "✓ real SMBIOS written into libvirt's win11 domain (repo file untouched)"
rm -f "$TMP"
echo "  system-serial=$SYS_SERIAL  uuid=$SYS_UUID  board=$BRD_SERIAL  chassis=$CHS_SERIAL"
