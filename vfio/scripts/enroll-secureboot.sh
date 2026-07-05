#!/usr/bin/env bash
# enroll-secureboot.sh — build the per-VM OVMF VARS with Microsoft Secure Boot keys enrolled.
# Win11 + kernel-anti-cheat attestation want real Secure Boot. Arch's OVMF ships without MS
# keys, so we enroll them into the domain's NVRAM file.
#
#   sudo ./vfio/scripts/enroll-secureboot.sh
# Needs: python-virt-firmware (yay -S virt-firmware). Do this while the VM is shut off.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run as root (sudo)"; exit 1; }
VARS_TMPL="/usr/share/edk2/x64/OVMF_VARS.4m.fd"
VARS_OUT="/var/lib/libvirt/qemu/nvram/win11_VARS.fd"

command -v virt-fw-vars >/dev/null || { echo "install python-virt-firmware:  yay -S virt-firmware"; exit 1; }

mkdir -p "$(dirname "$VARS_OUT")"
# --enroll-redhat enrolls a PK + the Microsoft KEK/DB certs (the standard VM Secure Boot set).
virt-fw-vars \
  --input  "$VARS_TMPL" \
  --output "$VARS_OUT" \
  --secure-boot \
  --enroll-redhat

echo "Enrolled Secure Boot VARS -> $VARS_OUT"
echo "win11.xml already points its <nvram> here. Boot the VM and confirm in msinfo32:"
echo "  'Secure Boot State: On'."
