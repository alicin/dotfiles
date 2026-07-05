# Windows guest checklist (win11 passthrough VM)

Steps performed **inside Windows**. You're reusing the bare-metal install, so it already boots to
a desktop — these adapt it for the VM, the dGPU, and Looking Glass.

## 1. Drivers & guest tools (Phase 1, emulated GPU)
- Mount the **virtio-win** ISO (attached as a CD in `win11.xml`). Install:
  - **NetKVM** (virtio network) — Device Manager → the unknown Ethernet → update driver from the ISO.
  - **virtio-serial** + **Balloon**/**vioinput** as offered.
- Install **spice-guest-tools** (clipboard, dynamic resize during setup).
- Install the **IVSHMEM** driver: Device Manager → *System devices* → "PCI standard RAM Controller"
  (the IVSHMEM device) → update driver → point at the virtio-win ISO's `Balloon`? No — use the
  **Red Hat IVSHMEM** driver from the virtio-win ISO (`\guest-agent` / the `ivshmem` inf) or gnif's
  signed IVSHMEM driver. Confirm it binds (no yellow bang) before touching Looking Glass.

## 2. NVIDIA dGPU (Phase 2)
- After re-enabling the dGPU passthrough, install the **NVIDIA driver** (GeForce/Studio, matching
  the RTX 50-series mobile part).
- Device Manager → Display adapters → the NVIDIA GPU should be **Code 0**.
  - **Code 43** → dump+patch the vBIOS on the host (`vfio/scripts/vbios-dump.md`) and pass `<rom>`.
- **MSI mode** (lower interrupt latency): use *MSI Utility v3* (or regedit) to set
  `HKLM\SYSTEM\CurrentControlSet\Enum\PCI\…\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties\MSISupported = 1`
  for **both** the NVIDIA GPU **and** its **High Definition Audio** function. Reboot.

## 3. Virtual display (Phase 3 — mandatory, the dGPU is headless)
- Install **Parsec VDD** (0.45+) *or* **IddSampleDriver (ge9)**.
- **Pin it to the NVIDIA adapter** (Parsec VDD 0.45+ supports GPU selection).
- Add a **single locked mode = 2560×1600 @ 240 Hz** to the driver's EDID/`vdd_settings.xml`
  (avoid leaving 60 Hz / extra modes — match the LG client output refresh).
- Add it as a **secondary** display first; confirm Looking Glass captures it; **then** set it as the
  **primary** display (and, on the host, switch `<video>` to `none`).

## 4. Looking Glass host (Phase 3)
- Install the **B7 host** app (version-matched to the host client).
- Drop `guest/looking-glass-host.ini` next to `looking-glass-host.exe` (DXGI + D3D12).
- Install it **as a service** (the installer offers this) so capture runs at the lock screen.

## 5. Latency & anti-cheat hardening (Phase 4)
- **Disable** for lowest latency: Core Isolation / **Memory Integrity (HVCI)**, **VBS**
  (`msinfo32` should show "Virtualization-based security: Not enabled"), and per-game **Fullscreen
  Optimizations** (exe → Properties → Compatibility).
- Confirm **Secure Boot State: On** and **TPM 2.0** present (`msinfo32` / `tpm.msc`) — anti-cheats
  check these.
- Set the Windows **power plan** to High Performance / Ultimate.
- ⚠️ **Anti-cheat:** Vanguard/EAC/BattlEye/Ricochet/Faceit can detect this VM and **permanently ban**
  the account despite the hypervisor/SMBIOS spoofing. **Test each such game with a throwaway account
  before signing into a real one.** Some titles will simply never run here.

## Notes
- Booting the same install bare-metal and virtualized may trigger a Windows re-activation/driver
  reconfigure on the first switch each way — normal.
- Razer's 12 thumb buttons arrive as their default keypad output via evdev; for full Synapse
  remapping you'd instead USB-passthrough the dongle (higher latency, host loses the mouse).
