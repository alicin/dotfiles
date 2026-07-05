# Dumping the dGPU vBIOS (only if you hit Code 43)

A **muxless** laptop dGPU can't expose its ROM to the guest through the vfio BAR, so the
NVIDIA guest driver often falls back to reading the **system ACPI shadow** — which isn't
there in a VM → **Code 43**. The fix is to pass a dumped, header-stripped vBIOS via
`<rom file=…>` in `win11.xml`.

## Preferred: extract from the ASUS BIOS update (most reliable on a muxless laptop)

A live `/sys` dump is unreliable when the GPU boots in D3cold, so pull the ROM out of the
official firmware image instead:

1. Download the **GU605CP** BIOS from the ASUS support page (a `.CAP`/`.zip`).
2. Extract the embedded NVIDIA ROM:
   ```bash
   git clone https://github.com/coderobe/VBiosFinder
   cd VBiosFinder && ./vbiosfinder extract /path/to/GU605CP-ASUS-*.CAP
   # outputs one or more vbios_*.rom under output/
   ```
   Identify the NVIDIA one with `rom-parser`:
   ```bash
   git clone https://github.com/awilliam/rom-parser && cd rom-parser && make
   ./rom-parser ../VBiosFinder/output/vbios_XXXX.rom   # look for the 10de (NVIDIA) vendor id
   ```
3. Patch + install:
   ```bash
   ./vfio/scripts/vbios-patch.sh /path/to/vbios_XXXX.rom
   ```

## Fallback: live dump (try only if the BIOS extraction fails)

With the dGPU powered on (`supergfxctl -m Hybrid`, NOT Vfio) and bound to `nvidia`:
```bash
cd /sys/bus/pci/devices/0000:01:00.0
echo 1 | sudo tee rom
sudo cat rom > /tmp/nvidia_raw.rom
echo 0 | sudo tee rom
./vfio/scripts/vbios-patch.sh /tmp/nvidia_raw.rom
```
Verify the dump is non-empty and starts with `55 aa`. On many muxless laptops this dump is
truncated/garbage — that's why the BIOS-extraction path above is preferred.

After patching, uncomment the `<rom .../>` line on the GPU `<hostdev>` in `win11.xml`,
`virsh define vfio/win11.xml`, and reboot the guest.
