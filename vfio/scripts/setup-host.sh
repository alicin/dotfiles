#!/usr/bin/env bash
# ============================================================================
# setup-host.sh — one-shot, self-contained host provisioner for the win11
#                 GPU-passthrough + Looking Glass VM on h4l9000 (Arch).
#
# Run this ONCE after a fresh Arch install to rebuild the entire HOST side of
# the setup. The Windows guest lives on a passed-through physical NVMe, so its
# state (NVIDIA driver, Looking Glass host, MTT virtual display, IVSHMEM driver,
# guest tools) survives host reinstalls — this script does NOT touch the guest.
#
#   ./vfio/scripts/setup-host.sh              # do everything (default)
#   ./vfio/scripts/setup-host.sh --dry-run    # print what it would do, change nothing
#   ./vfio/scripts/setup-host.sh --no-packages / --no-kernel / --no-vm
#
# Idempotent and safe to re-run. It uses sudo per-command; you'll be asked for
# your password once (then it's cached). Package installs run --noconfirm, so
# apart from that one sudo prompt (and yay possibly building looking-glass) it
# needs no input.
#
# What it configures (all matching the KNOWN-WORKING live domain):
#   * packages (libvirt/qemu/swtpm/edk2 + looking-glass/supergfxctl via yay)
#   * user in libvirt/kvm/input groups
#   * kernel cmdline: intel_iommu=on iommu=pt   (systemd-boot entries)
#   * initramfs: keep vfio_pci OUT of mkinitcpio MODULES (supergfxd inserts it per switch)
#   * /etc/supergfxd.conf  (Vfio hot-plug: no_logind, vfio_save=false)
#   * /etc/tmpfiles.d/looking-glass.conf   (/dev/shm/looking-glass 0660 ali:kvm)
#   * libvirt hooks (dGPU hot-plug, NVMe bind, host mounts released, CPU isolation)
#   * qemu.conf runs QEMU as root (needed for the raw PCI passthrough)
#   * ~/.config/looking-glass/client.ini   (the low-latency client config)
#   * enable libvirtd + supergfxd + the default NAT network
#   * virsh define win11.xml
#
# NOTE: the Hyprland-side latency tuning is NOT here — it lives in the tracked
# Hyprland config (config/hypr/lua/{options,rules}.lua: allow_tearing, debug:vfr,
# the looking-glass-client `immediate` rule) which is symlinked into ~/.config,
# so it deploys with the normal dotfiles. See vfio/README.md § "Looking Glass /
# Hyprland tuning".
# ============================================================================
set -uo pipefail

# ---- args ------------------------------------------------------------------
DRY=0; DO_PKGS=1; DO_KERNEL=1; DO_VM=1
for a in "$@"; do case "$a" in
  --dry-run)     DRY=1 ;;
  --no-packages) DO_PKGS=0 ;;
  --no-kernel)   DO_KERNEL=0 ;;
  --no-vm)       DO_VM=0 ;;
  -h|--help)     awk 'NR>1{ if(/^#/){sub(/^# ?/,"");print} else exit }' "$0"; exit 0 ;;
  *) echo "unknown arg: $a"; exit 2 ;;
esac; done

VFIO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="$(cd "$VFIO_DIR/.." && pwd)"
TARGET_USER="${SUDO_USER:-$USER}"
REBOOT_NEEDED=0
TS="$(date +%Y%m%d-%H%M%S)"

say(){ printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
info(){ printf '    %s\n' "$*"; }
warn(){ printf '\033[1;33m    ! %s\033[0m\n' "$*"; }
run(){ if [ "$DRY" = 1 ]; then printf '    [dry] %s\n' "$*"; else eval "$@"; fi; }
backup_file(){ run "sudo cp -a '$1' '$1.bak-$TS'"; }   # timestamped backup of a file/dir

[ "$DRY" = 1 ] && say "DRY RUN — nothing will be changed"
say "Target user: $TARGET_USER   Repo: $REPO_DIR"
[ "$(hostnamectl --static 2>/dev/null || hostname)" = h4l9000 ] || \
  warn "hostname is not 'h4l9000' — device IDs / node paths below assume the ROG G16 GU605CP."

# ---------------------------------------------------------------------------
# 1. Packages
# ---------------------------------------------------------------------------
if [ "$DO_PKGS" = 1 ]; then
  say "Installing packages (repo via pacman, AUR via yay)"
  PAC=(libvirt qemu-base qemu-desktop qemu-ui-spice-app qemu-ui-spice-core \
       swtpm edk2-ovmf dnsmasq iptables-nft)
  run "sudo pacman -S --needed --noconfirm ${PAC[*]}"
  if command -v yay >/dev/null 2>&1; then
    run "yay -S --needed --noconfirm looking-glass supergfxctl"
  else
    warn "yay not found — install 'looking-glass' and 'supergfxctl' from the AUR manually."
  fi
  info "virtio-win: the win11.xml CD-ROM points at /var/lib/libvirt/images/virtio-win.iso"
  if [ ! -e /var/lib/libvirt/images/virtio-win.iso ]; then
    if [ -e /usr/share/virtio-win/virtio-win.iso ]; then
      run "sudo install -Dm644 /usr/share/virtio-win/virtio-win.iso /var/lib/libvirt/images/virtio-win.iso"
    else
      warn "no virtio-win.iso — 'yay -S virtio-win' or drop the ISO at /var/lib/libvirt/images/virtio-win.iso (only needed to (re)install guest drivers)."
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 2. Groups
# ---------------------------------------------------------------------------
say "Adding $TARGET_USER to libvirt / kvm / input groups"
groups_now=" $(id -nG "$TARGET_USER" 2>/dev/null) "   # fetch once, not per-group
for g in libvirt kvm input; do
  case "$groups_now" in
    *" $g "*) info "already in $g" ;;
    *) run "sudo gpasswd -a '$TARGET_USER' $g"; info "added to $g (re-login for it to take effect)" ;;
  esac
done

# ---------------------------------------------------------------------------
# 3. Kernel cmdline (IOMMU) + initramfs (vfio) — needs a reboot if changed
# ---------------------------------------------------------------------------
if [ "$DO_KERNEL" = 1 ]; then
  say "Kernel cmdline: intel_iommu=on iommu=pt (systemd-boot)"
  # Assumes hand-managed systemd-boot type-1 entries. On UKI / kernel-install /
  # sdboot-manage setups the entries are regenerated on kernel updates (dropping
  # these params) and the real source is /etc/kernel/cmdline — patch it there.
  if grep -q 'intel_iommu=on' /proc/cmdline; then
    info "already active in /proc/cmdline — nothing to do"
  else
    if compgen -G '/boot/loader/entries/*.conf' >/dev/null; then
      backup_file /boot/loader/entries
      for e in /boot/loader/entries/*.conf; do
        grep -q '^linux' "$e" 2>/dev/null || continue           # Linux entries only (skips windows.conf)
        grep -q 'intel_iommu=on' "$e" 2>/dev/null && continue
        info "patching $(basename "$e")"
        run "sudo sed -i '/^options /s/\$/ intel_iommu=on iommu=pt/' '$e'"
        REBOOT_NEEDED=1
      done
    else
      warn "no systemd-boot entries found — add 'intel_iommu=on iommu=pt' to your bootloader by hand."
    fi
  fi

  say "initramfs: keep vfio_pci OUT of mkinitcpio MODULES"
  # DO NOT front-load vfio_pci. supergfxd hot-plugs the dGPU: in Integrated mode the card is
  # removed from the bus and vfio-pci's `ids=` is (re)applied only when supergfxd modprobes it at
  # the -m Vfio switch. A resident-from-initramfs vfio_pci makes that modprobe a no-op — it keeps
  # whatever (empty) ids the initramfs modprobe.d snapshot had — so nothing binds and the prepare
  # hook times out. Leaving it out means each switch inserts it fresh with the current ids.
  MKC=/etc/mkinitcpio.conf
  if [ -f "$MKC" ] && grep -qE '^MODULES=.*vfio_pci' "$MKC"; then
    backup_file "$MKC"
    # drop vfio_pci / vfio / vfio_iommu_type1 from the MODULES=() array (in any order)
    run "sudo sed -i -E 's/^(MODULES=\\()(.*)\\)/\\1\\2)/; s/\\b(vfio_pci|vfio_iommu_type1|vfio)\\b ?//g; s/^(MODULES=\\() +/\\1/; s/ +\\)/)/' '$MKC'"
    run "sudo mkinitcpio -P"
    REBOOT_NEEDED=1
  elif [ -f "$MKC" ]; then
    info "vfio_pci already absent from MODULES=() — good"
  else
    warn "no $MKC (not mkinitcpio?) — ensure supergfxd can modprobe vfio_pci at switch time."
  fi
fi

# ---------------------------------------------------------------------------
# 4. /etc files
# ---------------------------------------------------------------------------
say "supergfxd.conf (Vfio hot-plug: no_logind=true, vfio_save=false)"
[ -f /etc/supergfxd.conf ] && backup_file /etc/supergfxd.conf
run "sudo install -Dm644 '$VFIO_DIR/etc/supergfxd.conf' /etc/supergfxd.conf"

say "tmpfiles: /dev/shm/looking-glass (0660 ali:kvm)"
run "sudo install -Dm644 '$VFIO_DIR/etc/tmpfiles.d/looking-glass.conf' /etc/tmpfiles.d/looking-glass.conf"
# the committed rule owns it 'ali'; template it if provisioning as a different user
[ "$TARGET_USER" = ali ] || run "sudo sed -i 's/ ali kvm / $TARGET_USER kvm /' /etc/tmpfiles.d/looking-glass.conf"
run "sudo systemd-tmpfiles --create /etc/tmpfiles.d/looking-glass.conf"

say "libvirt hooks (dGPU hot-plug, NVMe bind, host mounts released, CPU isolation)"
run "sudo install -Dm755 '$VFIO_DIR/hooks/qemu'       /etc/libvirt/hooks/qemu"
run "sudo install -Dm755 '$VFIO_DIR/hooks/prepare.sh' /etc/libvirt/hooks/vfio/prepare.sh"
run "sudo install -Dm755 '$VFIO_DIR/hooks/release.sh' /etc/libvirt/hooks/vfio/release.sh"

say "qemu.conf: run QEMU as root (needed for the raw PCI passthrough)"
QC=/etc/libvirt/qemu.conf
if [ -f "$QC" ]; then
  if grep -qE '^\s*user\s*=\s*"root"' "$QC" && grep -qE '^\s*group\s*=\s*"root"' "$QC"; then
    info "already user/group = root"
  else
    backup_file "$QC"
    run "sudo sed -i -E -e 's/^\\s*#?\\s*user\\s*=.*/user = \"root\"/' -e 's/^\\s*#?\\s*group\\s*=.*/group = \"root\"/' '$QC'"
  fi
  info "evdev input passthrough (deferred) will ALSO need the 3 Razer/keyboard nodes added to"
  info "cgroup_device_acl in $QC — see vfio/etc/libvirt-qemu.conf.snippet when you enable it."
fi

# ---------------------------------------------------------------------------
# 5. Looking Glass client config (host-side)
# ---------------------------------------------------------------------------
say "Looking Glass client.ini -> ~$TARGET_USER/.config/looking-glass/client.ini"
UHOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
run "install -Dm644 '$VFIO_DIR/client.ini' '$UHOME/.config/looking-glass/client.ini'"
run "chown -R '$TARGET_USER' '$UHOME/.config/looking-glass' 2>/dev/null || true"

# ---------------------------------------------------------------------------
# 6. Services + network
# ---------------------------------------------------------------------------
say "Enabling services + reloading"
run "sudo systemctl enable --now libvirtd.service"
# enable (don't --now) then restart so the freshly-installed supergfxd.conf is loaded
run "sudo systemctl enable supergfxd.service"
run "sudo systemctl restart supergfxd.service"
run "sudo udevadm control --reload && sudo udevadm trigger"
run "sudo virsh net-autostart default 2>/dev/null || true"
run "sudo virsh net-start default 2>/dev/null || true"

# ---------------------------------------------------------------------------
# 7. Define the VM
# ---------------------------------------------------------------------------
if [ "$DO_VM" = 1 ]; then
  say "Defining the win11 domain"
  if sudo virsh dominfo win11 >/dev/null 2>&1; then
    info "win11 already defined — re-defining to sync with vfio/win11.xml"
  fi
  run "sudo virsh define '$VFIO_DIR/win11.xml'"
  info "For max anti-cheat fidelity (optional): sudo $VFIO_DIR/scripts/spoof-smbios.sh"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
say "Done."
RB=""
if [ "$REBOOT_NEEDED" = 1 ]; then
  warn "REBOOT REQUIRED — kernel cmdline and/or initramfs changed (IOMMU/vfio)."
  RB="reboot, then "
fi
cat <<EOF

    Next:
      1. ${RB}re-login (for the new groups) if this was a fresh install.
      2. Launch:   win11
                   (starts win11 -> hook hot-plugs the dGPU + releases the NVMe,
                    then opens the Looking Glass client; shuts the VM down on exit)
      3. Optional de-risk check:  sudo ./vfio/scripts/preflight.sh

    The guest is untouched (it's on the passed-through physical NVMe). If you ever
    reinstall Windows too, follow vfio/guest/README.md to reinstall the guest tools.
EOF
