# VFIO — Win11 GPU-passthrough + Looking Glass (ROG Zephyrus G16 GU605CP / h4l9000)

Boots the **existing bare-metal Windows** in a KVM VM with the **NVIDIA dGPU (RTX 5070)** and the
**whole Samsung NVMe** passed through, viewed over **Looking Glass** at **2560×1600@240**. The dGPU
is normally **off (0 W)** and hot-plugged only for the VM via `supergfxctl`; the host stays on the
Intel Arc iGPU the whole time. Tuned for **low video + input latency**.

**Status: ✅ working.** GPU + NVMe passthrough, hot-plug up/down, Looking Glass at 2560×1600@240
with the stutter fixed (see [Looking Glass / Hyprland tuning](#looking-glass--hyprland-latency-tuning)).
Input is still **virtio** (evdev passthrough is wired but commented out — "Phase 4", deferred).

> Deeper rationale, hardware facts and the adversarial risk analysis live in the plan:
> `~/.claude/plans/i-wanna-create-a-jazzy-pelican.md`.

---

## Reproduce the whole host in one command

The Windows guest lives on a **passed-through physical NVMe**, so its state (NVIDIA driver, Looking
Glass host, MTT virtual display, IVSHMEM driver, guest tools) **survives host reinstalls**. After a
fresh Arch install, rebuilding the host side is one script:

```bash
./vfio/scripts/setup-host.sh        # idempotent; --dry-run to preview; asks for sudo once
# reboot IF it says so (only when it had to change the IOMMU cmdline / strip vfio from the initramfs)
./vfio/scripts/game.sh              # launch
```

That installs packages, sets the IOMMU kernel cmdline, keeps vfio_pci out of the initramfs (so
supergfxd inserts it with its `ids=` at each `-m Vfio` switch), deploys the
`/etc` files (supergfxd, tmpfiles, libvirt hooks), the Looking Glass `client.ini`, enables the
services, and `virsh define`s the VM. It **does not touch the guest**. The Hyprland-side latency
tuning is *not* in the script — it's tracked Hyprland config (see below) that deploys with the
normal dotfiles symlink. See [setup-host.sh details](#host-setup-script-setup-hostsh).

---

## Daily use

```bash
./vfio/scripts/game.sh
```
1. `virsh start win11` → the libvirt **prepare hook** runs: `supergfxctl -m Vfio` powers the dGPU up
   and binds `01:00.0`+`01:00.1` to `vfio-pci`, unmounts `/mnt/fat`, binds the NVMe `02:00.0`, and
   confines the host to CPUs 6–15 so the guest owns P-cores 0–5.
2. Launches `looking-glass-client` (fullscreen on eDP-1).
3. On client exit it `virsh shutdown win11` → the **release hook** rebinds the NVMe, remounts
   `/mnt/fat`, restores CPUs, and `supergfxctl -m Integrated` powers the dGPU back to **0 W**.

---

## Architecture (as-built)

| Layer | Choice | Notes |
|---|---|---|
| **Hot-plug** | `supergfxctl -m Vfio` / `-m Integrated`, driven by the libvirt hook | dGPU 0 W when idle; supergfxd owns the `vfio-pci` module lifecycle, so the hook does the GPU **before** the NVMe. |
| **Video → host** | Looking Glass B7, **ivshmem-plain** over `/dev/shm/looking-glass` (128 MiB) | *Not* kvmfr — the native libvirt `<shmem>` device is what's proven working here. kvmfr is an optional latency upgrade (see below). |
| **Guest display** | **MTT Virtual Display Driver** @ **2560×1600@240**, captured by the LG host (DXGI + D3D12) | Emulated `<video vga>` is kept as the OVMF/boot console; the VDD is the surface LG captures. NvFBC is impossible on GeForce. |
| **Input** | virtio mouse + keyboard (through the LG client) | evdev passthrough (Razer Naga + keyboard, Ctrl+Ctrl grab) is present-but-commented in `win11.xml` for later. |
| **CPU** | 6 vCPUs pinned 1:1 → P-cores 0–5; emulator/iothread → E-cores 6–7; `host-passthrough`+`invtsc` | host dynamically confined to CPUs 6–15 while the VM runs (not `isolcpus`). |
| **Memory** | 20 GiB, **THP-backed** (`nosharepages` + `allocation immediate`) | no explicit 2M hugepage pool (20 GiB isn't reliably allocatable as 2M at runtime on 30 GiB). |
| **Disk** | whole Samsung NVMe **controller** `02:00.0` via PCI `<hostdev>` | native NVMe driver in-guest; boots bare-metal Windows directly. `/mnt/fat` (same disk) is unmounted for the session. |
| **`maxphysaddr`** | **`limit=39`** | the RTX 5070's 8 GiB BAR + ivshmem must fit where vfio can DMA-map. 39 works; 42 crashed on start (`vfio_container_dma_map = -22`). **Don't raise without re-testing a cold start.** |
| **Firmware** | q35 + OVMF secboot + swtpm TPM 2.0 (CRB) | Secure Boot on; MS keys not enrolled (guest works without). |
| **SMBIOS** | spoofed to a real ROG G16 (generic serials committed) | `scripts/spoof-smbios.sh` writes the machine's *real* serials into libvirt's private copy only. |

---

## Looking Glass / Hyprland latency tuning

This is the part that took the most iteration — the guest streamed fine but **stuttered/froze
whenever the host desktop was idle** (mouse still, video controls faded), and went smooth again on
any pointer/UI activity. Smooth in GNOME, broken in Hyprland → it was **host-compositor frame
pacing**, not the guest. Three settings fix it; all are tracked config, so they redeploy
automatically:

### Client side — `~/.config/looking-glass/client.ini` (source: `vfio/client.ini`)
| Setting | Value | Why |
|---|---|---|
| `win:jitRender` | **`no`** | **The fix.** jitRender times each render to just before vblank using compositor frame callbacks; on Hyprland those callbacks stall when the desktop is idle, so the client stops pulling guest frames until you move the mouse → stutter/freeze. `no` = render frames as they arrive, decoupled from callback pacing. |
| `egl:vsync` | `no` | present immediately (needs Hyprland tearing, below, or it just queues). |
| `app:renderer` | `EGL` | best path on the Intel Arc host; **don't** switch to OpenGL/gamescope (that advice is for NVIDIA-hosted compositors and adds latency here). |
| `app:shmFile` | `/dev/shm/looking-glass` | matches the `<shmem>` device in `win11.xml`. |

### Compositor side — `config/hypr/lua/hosts/h4l9000.lua` (symlinked into `~/.config/hypr`)
All three moved out of the global `options.lua`/`rules.lua` into the h4l9000 host file on
2026-08-07, so the tablet doesn't pay for them.

| Setting | Why |
|---|---|
| `general { allow_tearing = true }` | lets the fullscreen LG client tear; without it `egl:vsync=no` is negated and frames queue to vblank. |
| `immediate` window rule for `^(looking-glass-client)$` | actually engages tearing for the LG window. |
| `debug { vfr = false }` | Hyprland's variable-frame-rate **idle throttle** drops its render rate when the screen looks idle and starves the client — this was the *big* few-FPS collapse. VFR moved from `misc:vfr` to **`debug:vfr`** in 0.55. Cost: slightly higher idle GPU/power. |

### Gotchas learned (so we don't re-derive them)
- **`<video><model type='none'/>` is a trap while the VDD is unproven.** Tried 2026-08-16 and
  reverted the same day: without a monitor on the dGPU's HDMI the VDD becomes the *only* possible
  head, and when it doesn't come up the guest boots to zero displays — no LG session, no guest
  agent, no DHCP lease, and no response to ACPI shutdown. It also removes the only host-side view
  (`virsh screenshot` and SPICE need a display device), so you cannot see what went wrong. Keep
  `vga` until the VDD is verified, and test with a monitor attached.
- **The guest has no `looking-glass-host.ini`, despite `guest/README.md` saying to deploy one.**
  The LG host therefore runs on defaults and picks the **D12** capture backend, not `dxgi`. That is
  the configuration that has actually been working — don't "fix" it blind. The log's
  `Trying:`/`Using:` lines tell you which backend is live. (Related: `d3d12CopyDevice=1` in the
  repo's ini is out of range — the guest enumerates exactly one D3D12 adapter, since an emulated
  vga has no D3D12 driver and never appears in that enumeration.)
- **The VDD's `vdd_settings.xml` in the guest is not pinned** (`<friendlyname>default`) and offers
  6 resolutions × 7 refresh rates, both contrary to `guest/README.md`. Left as-is because it is the
  known-working state; pinning it to `NVIDIA GeForce RTX 5070 Laptop GPU` and locking one mode was
  tried on 2026-08-16 and is unproven (it was rolled back together with the `video=none` change, so
  which of the two broke the headless boot was never isolated).
- **A VM that dies ~30 s in is probably `game.sh`, not a crash.** The old launcher started the
  client immediately after `virsh start` and shut the VM down on *any* client exit — so "LG showed
  nothing and then it crashed" was really "the client quit while the guest was still booting, and
  the trap powered it off". Tell them apart from the qemu log: `reason=shutdown` is a graceful ACPI
  request (i.e. us), `reason=crashed`/`destroyed` is not. Fixed 2026-08-16; `game.sh` now waits for
  the LGMP magic in `/dev/shm/looking-glass` and leaves a non-attaching VM running.
- **The LGMP magic in the shm survives a VM shutdown.** Any readiness check must zero the first 16
  bytes before boot, or last session's header reads as "guest is ready" instantly.
- **qemu segfaults on teardown, intermittently.** Seen on 2026-08-16 at 15:37 and 16:07 (`SEGV_ACCERR`,
  `ip` == fault address) but not on every shutdown. It happens *after* the shutdown request, so it
  costs nothing but a coredump — don't mistake it for the guest failing.
- **A dirty NTFS volume blocks host-side inspection.** After a guest bugcheck, `ntfs-3g` refuses rw
  ("Metadata kept in Windows cache"). `sudo ntfsfix /dev/nvme0n1p3` resets the journal and schedules
  a chkdsk on the next Windows boot; prefer it over `ntfsfix -d`, which just clears the dirty flag
  and skips the verification. The VM must be off and `02:00.0` back on the `nvme` driver first.
- **`hyprctl keyword` is disabled with the Lua config parser** (*"keyword can't work with
  non-legacy parsers. Use eval."*) and there is no runtime `eval`. So options can only be set at
  config-load time (`hyprctl reload` after editing the `.lua`). A per-session VFR toggle from a
  script is therefore **not possible** — `debug:vfr=false` must live in the always-on config, not
  in `game.sh`.
- **HyprPanel was a red herring.** Its bar composites over the fullscreen window, but stopping it
  did *not* fix the stutter; `jitRender=no` did. (If you ever do want to stop it: it's an
  astal/`gjs` app, so `pkill hyprpanel` misses it — use `/usr/bin/hyprpanel quit`.)
- **Host env vars are already correct** for the Intel host (`LIBVA_DRIVER_NAME=iHD`,
  `__GLX_VENDOR_LIBRARY_NAME=mesa`); do **not** set them to `nvidia` (that's for NVIDIA-hosted
  Hyprland and would break host video/GL). `WLR_DRM_NO_ATOMIC` does nothing — Hyprland dropped the
  wlroots backend.

### 2560×1600@240
Set in the guest's MTT VDD config (`C:\VirtualDisplayDriver\vdd_settings.xml`, global refresh rates
include 240) and applied to the desktop with `ChangeDisplaySettingsEx`. The QEMU guest agent runs
in **session 0** and can't change the interactive desktop mode, so the refresh change is applied via
a transient scheduled task running in the logged-in user's session. Host eDP-1 is already 240 Hz.

### Optional latency upgrade: kvmfr
The lower-latency path is the **kvmfr** kernel module (`/dev/kvmfr0`, DMABUF import into the Arc
iGPU, no CPU memcpy) instead of `/dev/shm`. The module files live in `vfio/etc/` (modprobe/udev/
modules-load) but are **not deployed by default** because `/dev/shm` is what's proven working. To
switch: `yay -S looking-glass-module-dkms`, deploy those `etc/` files, set the `<shmem>` device to
back onto `/dev/kvmfr0`, and point `client.ini` at `shmFile=/dev/kvmfr0`.

---

## Files

| Path | What |
|---|---|
| `win11.xml` | libvirt domain — mirrors the working live domain (q35+OVMF secboot+swtpm, 6 P-core pin, hyperv, `maxphysaddr=39`, native `<shmem>`, dGPU+NVMe hostdevs, virtio input; evdev + anti-cheat hardening commented for later). |
| `scripts/setup-host.sh` | **One-shot host provisioner** — packages, IOMMU cmdline, initramfs, `/etc` files, hooks, `client.ini`, services, `virsh define`. Idempotent, `--dry-run`. |
| `scripts/game.sh` | Launcher: start VM → Looking Glass → shut down cleanly on client exit. |
| `hooks/qemu`, `hooks/prepare.sh`, `hooks/release.sh` | libvirt hook: hot-plug dGPU + NVMe, unmount/remount `/mnt/fat`, THP compaction, CPU isolation. |
| `client.ini` | Host Looking Glass client config (`jitRender=no`, `vsync=no`, EGL) → `~/.config/looking-glass/`. |
| `etc/tmpfiles.d/looking-glass.conf` | Creates `/dev/shm/looking-glass` `0660 ali:kvm` each boot (so QEMU writes / the client reads). |
| `etc/supergfxd.conf` | `vfio_enable=true`, `vfio_save=false`, `no_logind=true`. |
| `etc/modprobe.d/kvmfr.conf`, `etc/modules-load.d/kvmfr.conf`, `etc/udev/rules.d/99-kvmfr.rules` | **Optional** kvmfr path (not used by default — see above). |
| `etc/modprobe.d/vfio-dgpu.conf` | **Conditional** `disable_idle_d3=1` — only if the dGPU fails to resume from D3cold (the "works once per boot" reset quirk). |
| `etc/libvirt-qemu.conf.snippet` | `cgroup_device_acl` entries for the optional **evdev** input nodes and the **kvmfr** device. |
| `scripts/preflight.sh` | Phase-0 de-risk (iommu=pt gate, PCI IDs, IOMMU-group cleanliness, reset round-trip). |
| `scripts/spoof-smbios.sh` | Write the machine's real ROG serials into libvirt's private domain copy. |
| `scripts/enroll-secureboot.sh` | Enroll MS Secure Boot keys into the VM's NVRAM. |
| `scripts/vbios-patch.sh` + `vbios-dump.md` | Extract/patch the dGPU vBIOS (only if the guest shows Code 43). |
| `guest/looking-glass-host.ini`, `guest/README.md` | Windows-side host config + full guest checklist. |

---

## Host setup script (`setup-host.sh`)

Run separately from the dotfiles profile (intentionally — it's system-level VM plumbing, kept out
of `profile-install.sh`). Idempotent; re-run any time. Flags: `--dry-run`, `--no-packages`,
`--no-kernel`, `--no-vm`. What it does, in order:

1. **Packages** — `libvirt qemu-* swtpm edk2-ovmf dnsmasq iptables-nft` (pacman) + `looking-glass
   supergfxctl` (yay), all `--noconfirm`. Copies `virtio-win.iso` into place if the package has it.
2. **Groups** — adds you to `libvirt`, `kvm`, `input`.
3. **Kernel cmdline** — ensures `intel_iommu=on iommu=pt` on the systemd-boot Linux entries (backs
   up `entries/` first; skips `windows.conf`). **Reboot** if it changed anything.
4. **initramfs** — strips `vfio_pci vfio vfio_iommu_type1` from `mkinitcpio.conf` MODULES, rebuilds.
   (Front-loading vfio_pci makes supergfxd's per-switch `modprobe` a no-op, so the `ids=` never
   registers and the dGPU never binds — the prepare hook then times out. Let supergfxd own it.)
5. **`/etc`** — `supergfxd.conf`, the `/dev/shm/looking-glass` tmpfiles rule, the libvirt hooks,
   and `qemu.conf` set to run QEMU as root (needed for raw PCI passthrough).
6. **client.ini** → `~/.config/looking-glass/`.
7. **Services** — enables `libvirtd` + `supergfxd`, starts the default NAT network.
8. **`virsh define win11.xml`**.

The only interaction is the one sudo prompt (and yay possibly building `looking-glass`). It prints
**REBOOT REQUIRED** only when it touched the cmdline/initramfs.

---

## Guest side (persists across host reinstalls)

Nothing to redo normally — it's on the passed-through NVMe. If you ever reinstall **Windows** too,
`guest/README.md` is the checklist: virtio-win + IVSHMEM driver, NVIDIA driver, MTT Virtual Display
Driver locked to **2560×1600@240** on the NVIDIA adapter, Looking Glass **B7 host** as a SYSTEM
service, disable VBS/HVCI/Memory-Integrity + Fullscreen Optimizations.

---

## ⚠️ Read before you start (from-scratch / risk notes)

- **2026 Blackwell muxless laptop, almost no public passthrough track record** — treat bring-up as
  empirical. Run `sudo ./vfio/scripts/preflight.sh` first; it fails fast on the real blockers.
- **`iommu=pt` may block the Blackwell vfio bind** on some kernels. If the dGPU won't bind, drop
  `iommu=pt` (keep `intel_iommu=on`), reboot, retry. (It works *with* `iommu=pt` on the current kernel.)
- **Patched vBIOS** may be needed (muxless ROM shadow → Code 43): `scripts/vbios-dump.md`, then
  uncomment `<rom .../>` on the GPU hostdev in `win11.xml`.
- **Reset bug**: the dGPU may only work once per host boot. Acceptance gate = start the VM twice.
- **Anti-cheat = permanent ban risk.** Kernel anti-cheats (Vanguard/Valorant, EAC, BattlEye,
  Ricochet, Faceit) detect passthrough VMs **even with** hardening, and bans are permanent +
  hardware-tied. **Test each title on a throwaway account.** The hyperv `vendor_id` spoof and
  `<kvm><hidden>` are commented in `win11.xml` — enable only if needed. Honest fallback for
  Vanguard-class titles: boot Windows bare-metal (the `windows.conf` systemd-boot entry exists).
- **`/mnt/fat` is on the passed-through disk.** While the VM runs it is unmounted and the whole NVMe
  belongs to Windows. The prepare hook **refuses to start** if it can't unmount it (two kernels
  writing one disk = corruption).

### Building from scratch (phased)
1. **De-risk:** `setup-host.sh` then `sudo preflight.sh` (Vfio↔Integrated round-trip, clean IOMMU
   group, start-twice).
2. **Boot Windows (no dGPU):** comment the two dGPU `<hostdev>` blocks, `virsh define`, boot off the
   passed NVMe, install virtio-win + spice-guest-tools.
3. **dGPU:** re-enable the hostdevs, boot, install NVIDIA driver. Code 43 → patch vBIOS. Gate: start
   twice in one host boot.
4. **Looking Glass:** MTT VDD @ 2560×1600@240 (primary), IVSHMEM driver, LG B7 host service; host
   side is already done by `setup-host.sh`. Apply the [tuning above](#looking-glass--hyprland-latency-tuning).
5. **Input/hardening (deferred):** uncomment the evdev `<input>` blocks + add their nodes to
   `cgroup_device_acl`; optionally enable the SMBIOS/hyperv/kvm hardening.

---

## Recovery

- **VM won't start, `FATAL: timeout waiting for dGPU on vfio-pci`** (`journalctl -t vfio-hook`) → vfio_pci
  is resident before supergfxd's switch, so its `ids=` never applied. Usually a kernel upgrade rebuilt
  the initramfs with vfio_pci front-loaded. Fix: `grep MODULES= /etc/mkinitcpio.conf` should be `MODULES=()`
  (re-run `setup-host.sh` to strip + rebuild), then reboot. Verify with `lsinitcpio /boot/initramfs-linux-zen.img | grep vfio.*\.ko` (should be empty).
- **dGPU wedged / won't power down** → `supergfxctl -m Integrated`; if that fails, **reboot** (Blackwell reset bug).
- **`/mnt/fat` missing after a crash** → `sudo /etc/libvirt/hooks/vfio/release.sh` re-runs the rebind + remount.
- **Looking Glass shows a black/stale frame** → relaunch `looking-glass-client`; ensure the guest MTT VDD is active (2560×1600@240).
- **Stutter is back after a config change** → confirm `client.ini` has `jitRender=no`, and `hyprctl getoption debug:vfr` / `general:allow_tearing` are `false` / `true` (reload Hyprland if not).
- **Manual dGPU bind (no supergfxctl)** → `bin/vfio-bind.sh` / `bin/vfio-unbind.sh` at the repo root.
