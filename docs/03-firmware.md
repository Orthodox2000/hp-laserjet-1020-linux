# 03 — The firmware (the actual fix)

## Why a printer needs "firmware" uploaded

Most printers contain a full controller with its own CPU, RAM and firmware in flash, and
they understand a page description language (PostScript, PCL, ...). The host just sends a
document.

The **HP LaserJet 1020 is a "host-based" / "GDI" printer**. It is intentionally dumb: it
has a small RAM buffer, no flash-resident firmware, and no page language. Instead, the host
CPU does the rendering and the host **uploads the printer's runtime firmware into the
printer's RAM over USB at the start of every power-on cycle**.

```
 power on ──► printer sits in "boot" state (no FWVER)
                      │
     host uploads sihp1020.dl  (this is the missing step)
                      ▼
              printer runs, reports FWVER:20080222
                      │
              host sends rendered print job
```

That is why:

- Windows "just works" (HP's driver uploads the firmware with each job),
- Linux reports success but prints nothing when the file is missing,
- the printer forgets everything after a power cycle.

The same architecture is used by many cheap lasers (HP LJ 1000/1005/1018/1020/1022,
Canon LBP-2900/3000, ...). The `foo2zjs` project supports them.

## What file you need

```
/var/lib/foo2zjs/firmware/sihp1020.dl
```

- Size: **128999 bytes**
- md5: `0cd1ac3a4f6cb7995e99deffff840927`
- Format: **ACL/PJL** (a.k.a. "PJL-wrapped"), first bytes are ASCII (a date string), not ELF.

This repo ships it at [`../firmware/sihp1020.dl`](../firmware/sihp1020.dl).

## How to obtain/generate it yourself

### Option A — use the bundled file

```bash
sudo install -d -m 755 /var/lib/foo2zjs/firmware
sudo install -m 644 firmware/sihp1020.dl /var/lib/foo2zjs/firmware/sihp1020.dl
```

### Option B — from HPLIP (recommended if you don't trust a binary)

HP's own HPLIP ships the firmware gzipped as `hp_laserjet_1020.fw.gz`. It may already be on
your machine, on the printer's install CD, or in a backup. Decompress it:

```bash
gunzip -c hp_laserjet_1020.fw.gz > sihp1020.dl
md5sum sihp1020.dl      # expect 0cd1ac3a4f6cb7995e99deffff840927
```

That decompressed file is byte-for-byte identical to the correct `sihp1020.dl`.

### Option C — convert with `arm2hpdl` (understand the trap!)

`foo2zjs` ships `arm2hpdl`, which converts firmware images. **It has two very different
output paths** depending on the input's first bytes:

| Input starts with | `arm2hpdl` output header | Works on LJ 1020? |
|---|---|---|
| `\x7fELF` (ELF binary, e.g. from a Windows driver) | `beef` / ELF format | **NO** |
| ASCII date like `20...` (HPLIP `.fw`) | **ACL/PJL** format | **YES** |

If you feed it an ELF and upload the result, the printer **accepts the bytes and returns
success** but never runs — no `FWVER`, no print. This is the single most confusing failure
mode.

So if you have the Windows driver's raw firmware (ELF), converting it with `arm2hpdl`
gives the **wrong** (beef) format. Prefer Option B (HPLIP's `.fw.gz`) or the bundled file.

## Verify the installed firmware

```bash
md5sum /var/lib/foo2zjs/firmware/sihp1020.dl
# 0cd1ac3a4f6cb7995e99deffff840927

# first bytes should be ASCII/date, not ELF:
head -c 8 /var/lib/foo2zjs/firmware/sihp1020.dl | xxd
```

## How the firmware gets uploaded automatically

The `printer-driver-foo2zjs` package installs a udev rule and a helper script:

- `/usr/lib/udev/rules.d/85-hplj10xx.rules`
- `/usr/lib/udev/hplj1020` → symlink to `hplj1000`

On USB "add", the rule runs `hplj1020`, which:

1. waits ~6 s for the device to settle,
2. lists USB printer devices (via the CUPS `usb` backend, or `usblp`),
3. **skips any device that already reports `FWVER`** (firmware already loaded),
4. otherwise uploads `/var/lib/foo2zjs/firmware/sihp<model>.dl`.

Because of (3), running the loader when the printer is already up is a silent no-op — that
is normal and does **not** mean it's broken.

Manual upload (useful for testing):

```bash
# via the CUPS usb backend, no usblp needed
sudo DEVICE_URI='usb://HP/LaserJet%201020?serial=<PRINTER_SERIAL>' \
     /usr/lib/cups/backend/usb 1 1 1 1 '' /var/lib/foo2zjs/firmware/sihp1020.dl
```

### Prevent HPLIP from fighting foo2zjs

If HPLIP is installed, `/usr/lib/udev/rules.d/56-hpmud.rules` also reacts to the printer and
runs `hp-config_usb_printer`, which tries to download firmware using HPLIP's proprietary
plugin. On systems without the plugin it retries and can hold the USB device, racing the
foo2zjs loader. Neutralise it:

```bash
# stop HPLIP's helper from running on this printer
sudo sed -i 's|^\(ENV{hp_test}=="yes", PROGRAM=.*hp-config_usb_printer.*\)$|# disabled for foo2zjs: \1|' \
     /usr/lib/udev/rules.d/56-hpmud.rules
# and remove duplicate HPLIP firmware copies if present
sudo rm -f /usr/share/hplip/data/firmware/*.fw.gz
sudo udevadm control --reload-rules
```

`scripts/install-firmware.sh` does all of the above for you.

## Persistence across power cycles

Firmware lives in volatile RAM, so it must be re-uploaded after every printer power-on.
The udev rule handles USB attach. If you power the printer on/off **without** touching the
USB cable, some firmwares still trigger a USB re-enumeration, but to be safe you can also
re-run the loader or re-plug the cable.

To force the loader on demand:

```bash
sudo udevadm trigger --action=add --sysname-match='1-9'   # adjust to your USB path
# or simply re-plug the USB cable
```
